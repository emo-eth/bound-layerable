//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {VRFConsumerBaseV2} from 'chainlink/src/v0.8/VRFConsumerBaseV2.sol';
import {VRFCoordinatorV2Interface} from 'chainlink/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';
import {ERC721A} from 'bound-layerable/token/ERC721A.sol';

contract BatchVRFConsumer is ERC721A, Ownable {
    // VRF config
    uint256 constant MAX_BATCH = 8;
    uint16 constant NUM_CONFIRMATIONS = 7;
    uint32 constant CALLBACK_GAS_LIMIT = 100_000;
    uint64 immutable SUBSCRIPTION_ID;
    VRFCoordinatorV2Interface immutable COORDINATOR;

    // token config
    // use uint240 to ensure tokenId can never be > 2**248 for efficient hashing
    uint240 immutable MAX_NUM_SETS;
    uint8 immutable NUM_TOKENS_PER_SET;

    bytes32 public traitGenerationSeed;
    uint256 revealBatch;
    // allow unsafe revealing of an uncompleted batch, ie, in the case of a perpetually stalled mint
    bool forceUnsafeReveal;

    error MaxRandomness();
    error OnlyCoordinatorCanFulfill(address have, address want);
    error UnsafeReveal();

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
    }

    function setForceUnsafeReveal(bool force) public onlyOwner {
        forceUnsafeReveal = force;
    }

    function requestRandomWords(bytes32 keyHash)
        external
        onlyOwner
        returns (uint256)
    {
        uint256 nextTokenId_ = nextTokenId();
        uint256 numCompletedBatches = getRandomnessBatchForTokenId(
            nextTokenId_
        );
        // if equal, next batch has not started minting yet
        bool batchIsInProgress = nextTokenId_ >
            ((numCompletedBatches * (NUM_TOKENS_PER_SET * MAX_NUM_SETS)) / 8) &&
            numCompletedBatches != 8;

        uint32 _revealBatch = uint32(revealBatch);
        if (_revealBatch >= 8) {
            revert MaxRandomness();
        }
        if (_revealBatch > numCompletedBatches || (!batchIsInProgress)) {
            revert UnsafeReveal();
        }
        uint32 numToBatch = uint32(numCompletedBatches) - _revealBatch;

        if (
            (inProgressBatch == 0 || inProgressBatch == _revealBatch) &&
            !forceUnsafeReveal
        ) {
            // should not reveal a batch while it's in the process of minting
            revert UnsafeReveal();
        }
        if (numBatches > 0) {
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
        return 0;
    }

    // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
    // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
    // the origin of the call
    function rawFulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external onlyOwner {
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
        uint256 inProgressBatch = getRandomnessBatchForTokenId(nextTokenId());
        uint256 currBatch = revealBatch;
        if (
            (inProgressBatch == 0 || (currBatch >= inProgressBatch)) &&
            !forceUnsafeReveal
        ) {
            // should not reveal a batch while it's in the process of minting
            revert UnsafeReveal();
        }

        bytes32 currSeed = traitGenerationSeed;
        uint256 length = randomWords.length;
        uint256 maxRemainingBatches = MAX_BATCH - currBatch;
        uint256 stop = length > maxRemainingBatches
            ? maxRemainingBatches
            : length;
        for (uint256 i; i < stop; ) {
            uint256 randomness = randomWords[i];
            uint256 mask = (2**32 - 1) << (32 * currBatch);
            currSeed = bytes32(uint256(currSeed) | (randomness & mask));
            unchecked {
                currBatch += 1;
                ++i;
            }
        }
        traitGenerationSeed = currSeed;
        revealBatch = currBatch;
    }

    function nextTokenId() internal virtual returns (uint256) {
        return _nextTokenId();
    }

    function getRandomnessBatchForTokenId(uint256 tokenId)
        internal
        virtual
        returns (uint256 batchNumber)
    {
        // place immutable values onto stack
        uint256 maxNumSets = MAX_NUM_SETS;
        uint256 numTokensPerSet = NUM_TOKENS_PER_SET;
        assembly {
            batchNumber := div(
                tokenId,
                div(mul(maxNumSets, numTokensPerSet), 8)
            )
        }
    }
}
