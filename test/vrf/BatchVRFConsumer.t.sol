// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';

import {BatchVRFConsumer} from 'bound-layerable/vrf/BatchVRFConsumer.sol';
import {ERC20} from 'solmate/tokens/ERC20.sol';
import {VRFCoordinatorV2Interface} from 'chainlink/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import {MAX_INT, _32_MASK, BATCH_NOT_REVEALED_SIGNATURE} from 'bound-layerable/interface/Constants.sol';

contract BatchVRFConsumerImpl is BatchVRFConsumer {
    uint256 fakeNextTokenId;

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint240 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId
    )
        BatchVRFConsumer(
            name,
            symbol,
            vrfCoordinatorAddress,
            maxNumSets,
            numTokensPerSet,
            subscriptionId
        )
    {}

    function getNumTokensPerRandomBatch() public view returns (uint256) {
        return NUM_TOKENS_PER_RANDOM_BATCH;
    }

    function mintSets(uint256 numSets) public {
        setNextTokenIdWithBatch(numSets);
    }

    function setNextTokenId(uint256 nextTokenId_) public {
        fakeNextTokenId = nextTokenId_;
    }

    function setRevealBatch(uint32 batch) public {
        revealBatch = batch;
    }

    function getRevealBatch() public view returns (uint256) {
        return revealBatch;
    }

    function nextTokenId() internal virtual override returns (uint256) {
        return fakeNextTokenId;
    }

    function setNextTokenIdWithBatch(uint256 numSets) public {
        fakeNextTokenId = numSets * uint256(NUM_TOKENS_PER_SET);
    }

    function checkAndReturnNumBatches() public returns (uint32, uint32) {
        return _checkAndReturnNumBatches();
    }

    function writeRandomBatch(
        bytes32 seed,
        uint32 batch,
        uint256 randomness
    ) public pure returns (bytes32) {
        return _writeRandomBatch(seed, batch, randomness);
    }

    function getRandomnessForTokenIdPub(uint256 tokenId)
        public
        view
        returns (bytes32 randomness)
    {
        return getRandomnessForTokenId(tokenId);
    }

    function getRandomnessForBatchId(uint256 batchId)
        public
        view
        returns (bytes32)
    {
        return
            getRandomnessForTokenIdPub(batchId * NUM_TOKENS_PER_RANDOM_BATCH);
    }

    function setTraitGenerationSeed(bytes32 seed) public {
        traitGenerationSeed = seed;
    }

    function getRandomnessForTokenIdFromSeedPub(uint256 tokenId, bytes32 seed)
        public
        view
        returns (bytes32)
    {
        return getRandomnessForTokenIdFromSeed(tokenId, seed);
    }

    function noOp() public pure {}
}

contract BatchVRFConsumerTest is Test {
    BatchVRFConsumerImpl test;

    function setUp() public {
        test = new BatchVRFConsumerImpl(
            'test',
            'test',
            address(this),
            8000,
            7,
            1
        );
    }

    function testSetForceUnsafeReveal() public {
        test.setForceUnsafeReveal(true);
        vm.startPrank(address(1));
        vm.expectRevert('Ownable: caller is not the owner');
        test.setForceUnsafeReveal(false);
    }

    function testRequestRandomWords_onlyOwner(address addr) public {
        vm.startPrank(addr);
        vm.expectRevert('Ownable: caller is not the owner');
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testRequestRandomWords() public {
        test.mintSets(uint256(8000) / 8 + 1);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                100_000,
                1 // 1 batch
            ),
            abi.encode(10)
        );

        uint256 ret = test.requestRandomWords(bytes32(uint256(1)));
        assertEq(ret, 10);
    }

    function testRequestRandomWords(
        uint8 completedBatches,
        uint8 revealedBatches
    ) public {
        completedBatches = uint8(bound(completedBatches, 1, 8));
        revealedBatches = uint8(bound(revealedBatches, 0, 7));

        if (revealedBatches > completedBatches) {
            uint8 temp = revealedBatches;
            revealedBatches = completedBatches;
            completedBatches = temp;
        } else if (revealedBatches == completedBatches) {
            revealedBatches -= 1;
        }

        uint256 numSets = (uint256(8000) * completedBatches) / 8 + 1;
        test.mintSets(numSets);
        test.setRevealBatch(revealedBatches);

        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                100_000,
                completedBatches - revealedBatches
            ),
            abi.encode(10)
        );

        uint256 ret = test.requestRandomWords(bytes32(uint256(1)));
        assertEq(ret, 10);
    }

    function testRequestRandomWordsAllSomeBatched() public {
        test.mintSets(8000);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                100_000,
                8 // 8 batches
            ),
            abi.encode(10)
        );

        uint256 ret = test.requestRandomWords(bytes32(uint256(1)));
        assertEq(ret, 10);
    }

    function testRequestRandomWordsAllNoneBatched() public {
        test.mintSets(8000);
        test.setRevealBatch(2);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                100_000,
                6 // 6 batches
            ),
            abi.encode(10)
        );

        uint256 ret = test.requestRandomWords(bytes32(uint256(1)));
        assertEq(ret, 10);
    }

    function testRequestRandomWordsSomeNoneBatched() public {
        test.mintSets((uint256(8000) * 3) / 8 + 1);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                100_000,
                3 // 3 batches
            ),
            abi.encode(10)
        );

        uint256 ret = test.requestRandomWords(bytes32(uint256(1)));
        assertEq(ret, 10);
    }

    function testRequestRandomWordsSomeSomeBatched() public {
        test.mintSets((uint256(8000) * 3) / 8 + 1);
        test.setRevealBatch(1);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                100_000,
                2 // 2 batches
            ),
            abi.encode(10)
        );

        uint256 ret = test.requestRandomWords(bytes32(uint256(1)));
        assertEq(ret, 10);
    }

    function testRequestNoFullBatchMinted() public {
        vm.expectRevert(abi.encodeWithSignature('UnsafeReveal()'));
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testRequestNoFullBatchMinted_ForceUnsafe() public {
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                100_000,
                1 // 1 batch
            ),
            abi.encode(10)
        );
        test.setNextTokenId(1);
        test.setForceUnsafeReveal(true);
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testRequestMaxRandomness() public {
        test.mintSets(8000);
        test.setRevealBatch(8);
        vm.expectRevert(abi.encodeWithSignature('MaxRandomness()'));
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testWriteRandomBatch(
        bool emptySeed,
        uint8 batch,
        uint256 randomness
    ) public {
        // bound batch to [0,7]
        batch = uint8(bound(batch, 0, 7));
        bytes32 seed;
        // test that writing overwrites any previous randomness by supplying all 1's
        if (!emptySeed) {
            seed = bytes32(~uint256(0));
        }
        bytes32 newSeed = test.writeRandomBatch(seed, batch, randomness);
        // calculate bits to shift based on batch number
        uint256 shift = 32 * batch;
        // create mask for last 32 bits once shifted
        uint256 batchMask = 2**32 - 1;
        // get 32-bit randomness that should have been written
        uint256 maskedRandomness = (randomness >> shift) & batchMask;
        uint256 maskedSeed = (uint256(newSeed) >> shift) & batchMask;
        assertEq(maskedRandomness, maskedSeed);
    }

    function testCheckAndReturnNumBatches(
        uint8 numCompletedBatches,
        uint8 revealBatch,
        bool force
    ) public {
        numCompletedBatches = uint8(bound(numCompletedBatches, 0, 8));
        revealBatch = uint8(bound(revealBatch, 0, 8));

        test.setRevealBatch(revealBatch);

        uint256 numTokensToMint = test.getNumTokensPerRandomBatch() *
            uint256(numCompletedBatches);

        if (force) {
            numTokensToMint++;
            test.setForceUnsafeReveal(force);
        }
        test.setNextTokenId(numTokensToMint);

        bool maxRandomness = revealBatch == 8;
        bool revealAheadOfCompleted = revealBatch > numCompletedBatches;
        bool inProgressNoForce = revealBatch == numCompletedBatches && !force;

        if (maxRandomness) {
            vm.expectRevert(
                abi.encodeWithSelector(BatchVRFConsumer.MaxRandomness.selector)
            );
        } else if (revealAheadOfCompleted) {
            vm.expectRevert(BatchVRFConsumer.UnsafeReveal.selector);
        } else if (inProgressNoForce) {
            vm.expectRevert(BatchVRFConsumer.UnsafeReveal.selector);
        }
        (uint32 numMissingBatches, uint32 _revealBatch) = test
            .checkAndReturnNumBatches();

        bool shouldHaveReverted = maxRandomness ||
            revealAheadOfCompleted ||
            inProgressNoForce;

        if (!shouldHaveReverted) {
            uint256 expectedNumMissing = numCompletedBatches - revealBatch;
            if (force && numCompletedBatches != 8) {
                expectedNumMissing++;
            }
            assertEq(numMissingBatches, expectedNumMissing);
            assertEq(_revealBatch, revealBatch);
        }
    }

    function testRawFulfillRandomWords_onlyCoordinator(address _addr) public {
        vm.assume(_addr != address(this));
        vm.startPrank(_addr);
        vm.expectRevert(
            abi.encodeWithSignature(
                'OnlyCoordinatorCanFulfill(address,address)',
                _addr,
                address(this)
            )
        );
        test.rawFulfillRandomWords(1, new uint256[](2));
    }

    function testFulfillRandomWords(uint8 length) public {
        length = uint8(bound(length, 0, 8));
        test.setRevealBatch(3);
        test.mintSets(8000);
        uint256[] memory randomWords = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            unchecked {
                randomWords[i] = (i + 1) << (32 * (i + 3));
            }
        }
        test.rawFulfillRandomWords(1, randomWords);
        uint256 expectedEndBatch = length > 5 ? 8 : 3 + length;
        assertEq(test.getRevealBatch(), expectedEndBatch);
        for (uint8 i = 0; i < length; i++) {
            if (i > 4) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        BatchVRFConsumer.BatchNotRevealed.selector
                    )
                );
            }
            unchecked {
                assertEq(
                    uint256(test.getRandomnessForBatchId(i + 3)),
                    randomWords[i] >> (32 * (i + 3))
                );
            }
        }
    }

    function testGetRandomnessForTokenId(uint256 tokenId) public {
        tokenId = bound(tokenId, 0, 8000 - 1);
        uint256 randomness;
        for (uint256 i = 0; i < 8; i++) {
            randomness |= (i + 1) << (32 * i);
        }
        test.setTraitGenerationSeed(bytes32(randomness));
        bytes32 tokenRandomness = test.getRandomnessForTokenIdPub(tokenId);
        assertEq(
            uint256(tokenRandomness),
            (tokenId / test.getNumTokensPerRandomBatch()) + 1
        );
    }

    function test_snapshotGetRandomnessForTokenIdFromSeed() public view {
        test.getRandomnessForTokenIdFromSeedPub(uint256(1), bytes32(MAX_INT));
    }
}
