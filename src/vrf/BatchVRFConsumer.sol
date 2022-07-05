//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {VRFConsumerBaseV2} from 'chainlink/src/v0.8/VRFConsumerBaseV2.sol';
import {VRFCoordinatorV2Interface} from 'chainlink/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC721A} from 'bound-layerable/token/ERC721A.sol';

contract BatchVRFConsumer is ERC721A, Ownable {
    // VRF config
    uint256 constant MAX_BATCH = 8;
    uint16 constant NUM_CONFIRMATIONS = 7;
    uint32 constant CALLBACK_GAS_LIMIT = 100_000;
    uint64 immutable SUBSCRIPTION_ID;
    VRFCoordinatorV2Interface immutable COORDINATOR;

    // token config
    uint256 immutable MAX_NUM_SETS;
    uint256 immutable NUM_TOKENS_PER_SET;

    bytes32 public traitGenerationSeed;
    uint256 revealBatch;

    error MaxRandomness();
    error OnlyCoordinatorCanFulfill(address have, address want);
    error UnsafeReveal();

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint256 maxNumSets,
        uint256 numTokensPerSet,
        uint64 subscriptionId
    ) ERC721A(name, symbol) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        MAX_NUM_SETS = maxNumSets;
        NUM_TOKENS_PER_SET = numTokensPerSet;
        SUBSCRIPTION_ID = subscriptionId;
    }

    function requestRandomWords(bytes32 keyHash)
        external
        onlyOwner
        returns (uint256)
    {
        uint256 inProgressBatch = _nextTokenId() /
            ((MAX_NUM_SETS * NUM_TOKENS_PER_SET) / 8);
        if (inProgressBatch == 0) {
            // should not reveal a batch while it's in the process of minting
            revert UnsafeReveal();
        }
        if (inProgressBatch == MAX_BATCH) {
            revert MaxRandomness();
        }
        // get the number of batches to reveal, and number of random words to request
        uint32 numBatches = uint32(inProgressBatch - 1) - uint32(revealBatch);
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
        uint256 currBatch = revealBatch;
        bytes32 currSeed = traitGenerationSeed;
        uint256 length = randomWords.length;
        uint256 maxRemainingBatches = MAX_BATCH - currBatch;
        uint256 stop = length > maxRemainingBatches
            ? maxRemainingBatches
            : length;
        for (uint256 i; i < stop; ) {
            uint256 randomness = randomWords[i];
            uint256 mask = ((2**32 - 1) << (32 * currBatch));
            currSeed = bytes32(uint256(currSeed) | (randomness & mask));
            unchecked {
                currBatch += 1;
                ++i;
            }
        }
        traitGenerationSeed = currSeed;
        revealBatch = currBatch;
    }
}
