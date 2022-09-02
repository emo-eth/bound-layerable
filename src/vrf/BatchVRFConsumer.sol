// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {VRFConsumerBaseV2} from 'chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol';
import {VRFCoordinatorV2Interface} from 'chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import {TwoStepOwnable} from 'utility-contracts/TwoStepOwnable.sol';
import {ERC721A} from '../token/ERC721A.sol';
import {_32_MASK, BATCH_NOT_REVEALED_SIGNATURE} from '../interface/Constants.sol';
import {MaxRandomness, NoBatchesToReveal, RevealPending, OnlyCoordinatorCanFulfill, UnsafeReveal, NumRandomBatchesMustBePowerOfTwo, NumRandomBatchesMustBeGreaterThanOne} from '../interface/Errors.sol';
import {BitMapUtility} from '../lib/BitMapUtility.sol';
import {PackedByteUtility} from '../lib/PackedByteUtility.sol';

contract BatchVRFConsumer is ERC721A, TwoStepOwnable {
    // VRF config
    uint256 public immutable NUM_RANDOM_BATCHES;
    uint256 public immutable BITS_PER_RANDOM_BATCH;
    uint256 immutable BITS_PER_BATCH_SHIFT;
    uint256 immutable BATCH_RANDOMNESS_MASK;

    uint16 constant NUM_CONFIRMATIONS = 7;
    uint32 constant CALLBACK_GAS_LIMIT = 300_000;
    // todo: mutable?
    uint64 immutable SUBSCRIPTION_ID;
    VRFCoordinatorV2Interface immutable COORDINATOR;

    // token config
    // use uint240 to ensure tokenId can never be > 2**248 for efficient hashing
    uint240 immutable MAX_NUM_SETS;
    uint8 immutable NUM_TOKENS_PER_SET;
    uint248 immutable NUM_TOKENS_PER_RANDOM_BATCH;
    uint256 immutable MAX_TOKEN_ID;

    bytes32 public packedBatchRandomness;
    uint248 revealBatch;
    bool public pendingReveal;

    // allow unsafe revealing of an uncompleted batch, ie, in the case of a stalled mint
    bool forceUnsafeReveal;

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint240 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId,
        uint8 numRandomBatches
    ) ERC721A(name, symbol) {
        if (numRandomBatches < 2) {
            revert NumRandomBatchesMustBeGreaterThanOne();
        }
        NUM_RANDOM_BATCHES = numRandomBatches;
        BITS_PER_RANDOM_BATCH = uint8(uint256(256) / NUM_RANDOM_BATCHES);
        BITS_PER_BATCH_SHIFT = uint8(
            BitMapUtility.msb(uint256(BITS_PER_RANDOM_BATCH))
        );
        bool powerOfTwo = uint256(BITS_PER_RANDOM_BATCH) *
            uint256(NUM_RANDOM_BATCHES) ==
            256;
        if (!powerOfTwo) {
            revert NumRandomBatchesMustBePowerOfTwo();
        }
        BATCH_RANDOMNESS_MASK = ((1 << BITS_PER_RANDOM_BATCH) - 1);

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        MAX_NUM_SETS = maxNumSets;
        NUM_TOKENS_PER_SET = numTokensPerSet;
        SUBSCRIPTION_ID = subscriptionId;
        NUM_TOKENS_PER_RANDOM_BATCH =
            (uint248(MAX_NUM_SETS) * uint248(NUM_TOKENS_PER_SET)) /
            uint248(NUM_RANDOM_BATCHES);
        MAX_TOKEN_ID = uint256(MAX_NUM_SETS) * uint256(NUM_TOKENS_PER_SET);
    }

    /**
     * @notice when true, allow revealing the rest of a batch that has not completed minting yet
     *         This is "unsafe" because it becomes possible to know the layerIds of unminted tokens from the batch
     */
    function setForceUnsafeReveal(bool force) external onlyOwner {
        forceUnsafeReveal = force;
    }

    /**
     * @notice request random words from the chainlink vrf for each unrevealed batch
     */
    function requestRandomWords(bytes32 keyHash) external returns (uint256) {
        if (pendingReveal) {
            revert RevealPending();
        }
        (uint32 numBatches, ) = _checkAndReturnNumBatches();
        if (numBatches == 0) {
            revert NoBatchesToReveal();
        }

        // Will revert if subscription is not set and funded.
        uint256 _pending = COORDINATOR.requestRandomWords(
            keyHash,
            SUBSCRIPTION_ID,
            NUM_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            1
        );
        pendingReveal = true;
        return _pending;
    }

    function clearPendingReveal() external onlyOwner {
        pendingReveal = false;
    }

    function getRandomnessForTokenId(uint256 tokenId)
        internal
        view
        returns (bytes32 randomness)
    {
        return getRandomnessForTokenIdFromSeed(tokenId, packedBatchRandomness);
    }

    /**
     * @notice Get the 32-bit randomness for a given tokenId if it's been set
     * @param tokenId tokenId of the token to get the randomness for
     * @param seed bytes32 seed containing all batches randomness
     * @return randomness 32-bit randomness as bytes32 for the given tokenId
     */
    function getRandomnessForTokenIdFromSeed(uint256 tokenId, bytes32 seed)
        internal
        view
        returns (bytes32 randomness)
    {
        // put immutable variable onto stack
        uint256 numTokensPerRandomBatch = NUM_TOKENS_PER_RANDOM_BATCH;
        uint256 shift = BITS_PER_BATCH_SHIFT;
        uint256 mask = BATCH_RANDOMNESS_MASK;

        /// @solidity memory-safe-assembly
        assembly {
            // use mask to get last N bits of shifted packedBatchRandomness
            randomness := and(
                // shift packedBatchRandomness right by batchNum * bits per batch
                shr(
                    // get batch number of token, multiply by bits per batch
                    shl(shift, div(tokenId, numTokensPerRandomBatch)),
                    seed
                ),
                mask
            )
        }
    }

    // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
    // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
    // the origin of the call
    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        if (msg.sender != address(COORDINATOR)) {
            revert OnlyCoordinatorCanFulfill(msg.sender, address(COORDINATOR));
        }
        fulfillRandomWords(requestId, randomWords);
    }

    /**
     * @notice fulfillRandomness handles the VRF response. Your contract must
     * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
     * @notice principles to keep in mind when implementing your fulfillRandomness
     * @notice method.
     *
     * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
     * @dev signature, and will call it once it has verified the proof
     * @dev associated with the randomness. (It is triggered via a call to
     * @dev rawFulfillRandomness, below.)
     *
     * @param
     * @param randomWords the VRF output expanded to the requested number of words
     */
    function fulfillRandomWords(uint256, uint256[] memory randomWords)
        internal
        virtual
    {
        (uint32 numBatches, uint32 _revealBatch) = _checkAndReturnNumBatches();
        uint256 currSeed = uint256(packedBatchRandomness);
        uint256 randomness = randomWords[0];

        // we have revealed N batches; mask the bottom bits out
        uint256 mask;
        uint256 bitShift = BITS_PER_RANDOM_BATCH * _revealBatch;
        //  solidity will overflow and throw arithmetic error without this check
        if (bitShift != 256) {
            // will be 0 if bitshift == 256 (and would not overflow)
            mask = type(uint256).max ^ ((1 << bitShift) - 1);
        }
        // we need only need to reveal up to M batches; mask the top bits out
        bitShift = (BITS_PER_RANDOM_BATCH * (numBatches + _revealBatch));
        if (bitShift != 256) {
            mask = mask & ((1 << bitShift) - 1);
        }

        uint256 newRandomness = randomness & mask;
        currSeed = currSeed | newRandomness;

        _revealBatch += numBatches;

        // coerce any 0-slots to 1
        for (uint256 i; i < numBatches; ) {
            uint256 retrievedRandomness = PackedByteUtility.getPackedNFromRight(
                uint256(currSeed),
                BITS_PER_RANDOM_BATCH,
                i
            );
            if (retrievedRandomness == 0) {
                currSeed = PackedByteUtility.packNAtRightIndex(
                    uint256(currSeed),
                    BITS_PER_RANDOM_BATCH,
                    1,
                    i
                );
            }
            unchecked {
                ++i;
            }
        }

        packedBatchRandomness = bytes32(currSeed);
        revealBatch = _revealBatch;
        pendingReveal = false;
    }

    /**
     * @notice calculate how many batches need to be revealed, and also get next batch number
     * @return (uint32 numMissingBatches, uint32 _revealBatch) - number missing batches, and the current _revealBatch
     *         index (current batch revealed + 1, or 0 if none)
     */
    function _checkAndReturnNumBatches()
        internal
        view
        returns (uint32, uint32)
    {
        // get next unminted token ID
        uint256 nextTokenId_ = _nextTokenId();
        // get number of fully completed batches
        uint256 numCompletedBatches = nextTokenId_ /
            NUM_TOKENS_PER_RANDOM_BATCH;

        uint32 _revealBatch = uint32(revealBatch);
        // reveal is complete if _revealBatch is >= 8
        if (_revealBatch >= NUM_RANDOM_BATCHES) {
            revert MaxRandomness();
        }

        // if equal, next batch has not started minting yet
        bool batchIsInProgress = nextTokenId_ >
            numCompletedBatches * NUM_TOKENS_PER_RANDOM_BATCH &&
            numCompletedBatches != NUM_RANDOM_BATCHES;
        bool batchInProgressAlreadyRevealed = _revealBatch >
            numCompletedBatches;
        uint32 numMissingBatches = batchInProgressAlreadyRevealed
            ? 0
            : uint32(numCompletedBatches) - _revealBatch;

        // don't ever reveal batches from which no tokens have been minted
        if (
            batchInProgressAlreadyRevealed ||
            (numMissingBatches == 0 && !batchIsInProgress)
        ) {
            revert UnsafeReveal();
        }
        // increment if batch is in progress
        if (batchIsInProgress && forceUnsafeReveal) {
            ++numMissingBatches;
        }

        return (numMissingBatches, _revealBatch);
    }
}
