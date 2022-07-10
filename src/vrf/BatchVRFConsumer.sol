//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {VRFConsumerBaseV2} from 'chainlink/src/v0.8/VRFConsumerBaseV2.sol';
import {VRFCoordinatorV2Interface} from 'chainlink/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';
import {ERC721A} from 'bound-layerable/token/ERC721A.sol';
import {_32_MASK, BATCH_NOT_REVEALED_SIGNATURE} from 'bound-layerable/interface/Constants.sol';

contract BatchVRFConsumer is ERC721A, Ownable {
    // VRF config
    uint8 constant MAX_BATCH = 8;
    uint16 constant NUM_CONFIRMATIONS = 7;
    uint32 constant CALLBACK_GAS_LIMIT = 100_000;
    // todo: mutable?
    uint64 immutable SUBSCRIPTION_ID;
    VRFCoordinatorV2Interface immutable COORDINATOR;

    // token config
    // use uint240 to ensure tokenId can never be > 2**248 for efficient hashing
    uint240 immutable MAX_NUM_SETS;
    uint8 immutable NUM_TOKENS_PER_SET;
    uint248 immutable NUM_TOKENS_PER_RANDOM_BATCH;

    bytes32 public traitGenerationSeed;
    uint248 revealBatch;
    // allow unsafe revealing of an uncompleted batch, ie, in the case of a perpetually stalled mint
    bool forceUnsafeReveal;

    error MaxRandomness();
    error OnlyCoordinatorCanFulfill(address have, address want);
    error UnsafeReveal();
    error BatchNotRevealed();

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint240 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId
    ) ERC721A(name, symbol) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        MAX_NUM_SETS = maxNumSets;
        NUM_TOKENS_PER_SET = numTokensPerSet;
        SUBSCRIPTION_ID = subscriptionId;
        NUM_TOKENS_PER_RANDOM_BATCH =
            (uint248(MAX_NUM_SETS) * uint248(NUM_TOKENS_PER_SET)) /
            uint248(MAX_BATCH);
    }

    function setForceUnsafeReveal(bool force) public onlyOwner {
        forceUnsafeReveal = force;
    }

    function requestRandomWords(bytes32 keyHash)
        external
        onlyOwner
        returns (uint256)
    {
        (uint32 numBatches, ) = _checkAndReturnNumBatches();

        // Will revert if subscription is not set and funded.
        return
            COORDINATOR.requestRandomWords(
                keyHash,
                SUBSCRIPTION_ID,
                NUM_CONFIRMATIONS,
                CALLBACK_GAS_LIMIT,
                numBatches
            );
    }

    function getRandomnessForTokenId(uint256 tokenId)
        internal
        view
        returns (bytes32 randomness)
    {
        return getRandomnessForTokenIdFromSeed(tokenId, traitGenerationSeed);
    }

    function getRandomnessForTokenIdFromSeed(uint256 tokenId, bytes32 seed)
        internal
        view
        returns (bytes32 randomness)
    {
        // put immutable variable onto stack
        uint256 numTokensPerRandomBatch = NUM_TOKENS_PER_RANDOM_BATCH;
        assembly {
            // use mask to get last 32 bits of shifted traitGenerationSeed
            randomness := and(
                // shift traitGenerationSeed right by batchNum * 32 bits
                shr(
                    // get batch number of token, multiply by 32
                    mul(div(tokenId, numTokensPerRandomBatch), 32),
                    seed
                ),
                _32_MASK
            )
            if eq(randomness, 0) {
                let freeMem := mload(0x40)
                mstore(freeMem, BATCH_NOT_REVEALED_SIGNATURE)
                revert(freeMem, 4)
            }
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
        uint256 length = randomWords.length;
        uint256 stop = length > numBatches ? numBatches : length;
        bytes32 currSeed = traitGenerationSeed;
        for (uint256 i; i < stop; ) {
            uint256 randomness = randomWords[i];
            currSeed = _writeRandomBatch(currSeed, _revealBatch, randomness);
            unchecked {
                _revealBatch += 1;
                ++i;
            }
        }
        traitGenerationSeed = currSeed;
        revealBatch = _revealBatch;
    }

    function _checkAndReturnNumBatches() internal returns (uint32, uint32) {
        // get next unminted token ID
        uint256 nextTokenId_ = nextTokenId();
        // get number of fully completed batches
        uint256 numCompletedBatches = nextTokenId_ /
            NUM_TOKENS_PER_RANDOM_BATCH;

        uint32 _revealBatch = uint32(revealBatch);
        // reveal is complete if _revealBatch is >= 8
        if (_revealBatch >= MAX_BATCH) {
            revert MaxRandomness();
        }

        // if equal, next batch has not started minting yet
        bool batchIsInProgress = nextTokenId_ >
            numCompletedBatches * NUM_TOKENS_PER_RANDOM_BATCH &&
            numCompletedBatches != MAX_BATCH;
        bool batchInProgressAlreadyRevealed = _revealBatch >
            numCompletedBatches;
        uint32 numMissingBatches = batchInProgressAlreadyRevealed
            ? 0
            : uint32(numCompletedBatches) - _revealBatch;

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

    function _writeRandomBatch(
        bytes32 seed,
        uint32 batch,
        uint256 randomness
    ) internal pure returns (bytes32) {
        uint256 writeMask = uint256(_32_MASK) << (32 * batch);
        uint256 clearMask = ~writeMask;
        return bytes32((uint256(seed) & clearMask) | (randomness & writeMask));
    }

    function nextTokenId() internal virtual returns (uint256) {
        return _nextTokenId();
    }
}
