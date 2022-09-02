// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';

import {BatchVRFConsumer} from 'bound-layerable/vrf/BatchVRFConsumer.sol';
import {ERC20} from 'solmate/tokens/ERC20.sol';
import {VRFCoordinatorV2Interface} from 'chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import {MAX_INT, _32_MASK, BATCH_NOT_REVEALED_SIGNATURE} from 'bound-layerable/interface/Constants.sol';
import {MaxRandomness, RevealPending, NoBatchesToReveal, BatchNotRevealed, OnlyCoordinatorCanFulfill, UnsafeReveal, BatchNotRevealed, NumRandomBatchesMustBeGreaterThanOne, NumRandomBatchesMustBePowerOfTwo} from 'bound-layerable/interface/Errors.sol';
import {BitMapUtility} from 'bound-layerable/lib/BitMapUtility.sol';

contract BatchVRFConsumerImpl is BatchVRFConsumer {
    uint256 fakeNextTokenId;

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint240 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId,
        uint8 numRandomBatches
    )
        BatchVRFConsumer(
            name,
            symbol,
            vrfCoordinatorAddress,
            maxNumSets,
            numTokensPerSet,
            subscriptionId,
            numRandomBatches
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

    function _nextTokenId() internal view virtual override returns (uint256) {
        return fakeNextTokenId;
    }

    function setNextTokenIdWithBatch(uint256 numSets) public {
        fakeNextTokenId = numSets * uint256(NUM_TOKENS_PER_SET);
    }

    function checkAndReturnNumBatches() public view returns (uint32, uint32) {
        return _checkAndReturnNumBatches();
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

    function setPackedBatchRandomness(bytes32 seed) public {
        packedBatchRandomness = seed;
    }

    function getRandomnessForTokenIdFromSeedPub(uint256 tokenId, bytes32 seed)
        public
        view
        returns (bytes32)
    {
        return getRandomnessForTokenIdFromSeed(tokenId, seed);
    }
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
            1,
            16
        );
    }

    function testConstructorEnforcesPowerOfTwo() public {
        for (uint256 i = 0; i < 256; i++) {
            if (i < 2) {
                vm.expectRevert(NumRandomBatchesMustBeGreaterThanOne.selector);
            } else if ((256 / i) * i == 256) {
                // should pass
            } else {
                vm.expectRevert(NumRandomBatchesMustBePowerOfTwo.selector);
            }
            new BatchVRFConsumer(
                'test',
                'test',
                address(this),
                8000,
                7,
                1,
                uint8(i)
            );
        }
    }

    function testSetForceUnsafeReveal() public {
        test.setForceUnsafeReveal(true);
        vm.startPrank(address(1));
        vm.expectRevert(0x5fc483c5);
        test.setForceUnsafeReveal(false);
    }

    function testClearPendingReveal_onlyOwner(address addr) public {
        vm.assume(addr != address(this));
        vm.startPrank(addr);
        vm.expectRevert(0x5fc483c5);
        test.clearPendingReveal();
    }

    function testRequestRandomWords() public {
        test.mintSets(uint256(8000) / test.NUM_RANDOM_BATCHES() + 1);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                300_000,
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
        completedBatches = uint8(
            bound(completedBatches, 1, test.NUM_RANDOM_BATCHES())
        );
        revealedBatches = uint8(
            bound(revealedBatches, 0, test.NUM_RANDOM_BATCHES() - 1)
        );

        if (revealedBatches > completedBatches) {
            uint8 temp = revealedBatches;
            revealedBatches = completedBatches;
            completedBatches = temp;
        } else if (revealedBatches == completedBatches) {
            revealedBatches -= 1;
        }

        uint256 numSets = (uint256(8000) * completedBatches) /
            test.NUM_RANDOM_BATCHES() +
            1;
        test.mintSets(numSets);
        test.setRevealBatch(revealedBatches);

        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                300_000,
                1
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
                300_000,
                1
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
                300_000,
                1
            ),
            abi.encode(10)
        );

        uint256 ret = test.requestRandomWords(bytes32(uint256(1)));
        assertEq(ret, 10);
    }

    function testRequestRandomWordsSomeNoneBatched() public {
        test.mintSets((uint256(8000) * 3) / test.NUM_RANDOM_BATCHES() + 1);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                300_000,
                1
            ),
            abi.encode(10)
        );

        uint256 ret = test.requestRandomWords(bytes32(uint256(1)));
        assertEq(ret, 10);
    }

    function testRequestRandomWordsSomeSomeBatched() public {
        test.mintSets((uint256(8000) * 3) / test.NUM_RANDOM_BATCHES() + 1);
        test.setRevealBatch(1);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                300_000,
                1
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
                300_000,
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
        test.setRevealBatch(test.NUM_RANDOM_BATCHES());
        vm.expectRevert(abi.encodeWithSignature('MaxRandomness()'));
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testCheckAndReturnNumBatches(
        uint8 numCompletedBatches,
        uint8 revealBatch,
        bool force
    ) public {
        numCompletedBatches = uint8(
            bound(numCompletedBatches, 0, test.NUM_RANDOM_BATCHES())
        );
        revealBatch = uint8(bound(revealBatch, 0, test.NUM_RANDOM_BATCHES()));

        test.setRevealBatch(revealBatch);

        uint256 numTokensToMint = test.getNumTokensPerRandomBatch() *
            uint256(numCompletedBatches);

        if (force) {
            numTokensToMint++;
            test.setForceUnsafeReveal(force);
        }
        test.setNextTokenId(numTokensToMint);

        bool maxRandomness = revealBatch == test.NUM_RANDOM_BATCHES();
        bool revealAheadOfCompleted = revealBatch > numCompletedBatches;
        bool inProgressNoForce = revealBatch == numCompletedBatches && !force;

        if (maxRandomness) {
            vm.expectRevert(abi.encodeWithSelector(MaxRandomness.selector));
        } else if (revealAheadOfCompleted) {
            vm.expectRevert(UnsafeReveal.selector);
        } else if (inProgressNoForce) {
            vm.expectRevert(UnsafeReveal.selector);
        }
        (uint32 numMissingBatches, uint32 _revealBatch) = test
            .checkAndReturnNumBatches();

        bool shouldHaveReverted = maxRandomness ||
            revealAheadOfCompleted ||
            inProgressNoForce;

        if (!shouldHaveReverted) {
            uint256 expectedNumMissing = numCompletedBatches - revealBatch;
            if (force && numCompletedBatches != test.NUM_RANDOM_BATCHES()) {
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
            abi.encodeWithSelector(
                OnlyCoordinatorCanFulfill.selector,
                _addr,
                address(this)
            )
        );
        test.rawFulfillRandomWords(1, new uint256[](2));
    }

    function testFulfillRandomnessDoesnotOverWriteExistingSeed() public {
        test.setPackedBatchRandomness(bytes32(uint256(1)));
        test.setRevealBatch(3);
        test.mintSets(8000);
        uint256 randomWord;
        for (uint256 i = 0; i < 5; i++) {
            unchecked {
                // randomWords[i] = (i + 1) << (32 * (i + 3));
                randomWord |=
                    (i + 1) <<
                    (test.BITS_PER_RANDOM_BATCH() * (i + 3));
            }
        }
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        test.rawFulfillRandomWords(1, randomWords);
        // uint256 expectedEndBatch = length > 5 ? 8 : 3 + length;
        assertEq(test.getRevealBatch(), test.NUM_RANDOM_BATCHES());
        assertEq(test.getRandomnessForBatchId(0), bytes32(uint256(1)));
    }

    /// @dev test that rawFulfillRandomWords succeeds even when length might not match what is expected
    function testFulfillRandomWords(uint8 revealBatch, uint8 completedBatches)
        public
    {
        // length = uint8(bound(length, 0, 8));
        revealBatch = uint8(bound(revealBatch, 0, test.NUM_RANDOM_BATCHES()));
        completedBatches = uint8(
            bound(completedBatches, 0, test.NUM_RANDOM_BATCHES())
        );
        test.setRevealBatch(revealBatch);
        uint256 numSets = (uint256(8000) * completedBatches) /
            test.NUM_RANDOM_BATCHES() +
            1;
        test.mintSets(numSets);
        uint256 randomWord;
        // uint256[] memory randomWords = new uint256[](length);
        uint256 length = revealBatch > completedBatches
            ? 0
            : completedBatches - revealBatch;
        for (uint256 i = 0; i < length; i++) {
            unchecked {
                randomWord |= (i + 1) << (test.BITS_PER_RANDOM_BATCH() * (i));
            }
        }

        if (revealBatch >= test.NUM_RANDOM_BATCHES()) {
            vm.expectRevert(MaxRandomness.selector);
        } else if (revealBatch > completedBatches) {
            vm.expectRevert(UnsafeReveal.selector);
        }
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomWord;
        test.rawFulfillRandomWords(1, randomWords);
    }

    /// @dev test fulfilling all randomness at once
    function testFulfillRandomWords() public {
        uint256 length = test.NUM_RANDOM_BATCHES();
        test.setRevealBatch(0);
        test.mintSets(8000);
        uint256[] memory randomWords = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            unchecked {
                randomWords[i] = (i + 1) << (test.BITS_PER_RANDOM_BATCH() * i);
            }
        }
        test.rawFulfillRandomWords(1, randomWords);
    }

    function testGetRandomnessForTokenId(uint256 tokenId) public {
        tokenId = bound(tokenId, 0, 8000 - 1);
        uint256 randomness;
        for (uint256 i = 0; i < test.NUM_RANDOM_BATCHES(); i++) {
            randomness |= (i + 1) << (test.BITS_PER_RANDOM_BATCH() * i);
        }
        test.setPackedBatchRandomness(bytes32(randomness));
        bytes32 tokenRandomness = test.getRandomnessForTokenIdPub(tokenId);
        assertEq(
            uint256(tokenRandomness),
            (tokenId / test.getNumTokensPerRandomBatch()) + 1
        );
    }

    function testGetRandomnessForTokenId_notRevealed(uint256 tokenId) public {
        bytes32 randomness = test.getRandomnessForTokenIdPub(tokenId);
        assertEq(randomness, bytes32(0));
    }

    function test_snapshotGetRandomnessForTokenIdFromSeed1() public view {
        test.getRandomnessForTokenIdFromSeedPub(uint256(1), bytes32(MAX_INT));
    }

    function testRequestRandomness_NoBatchesToReveal() public {
        uint256 length = test.NUM_RANDOM_BATCHES();
        test.setRevealBatch(0);
        test.mintSets(7999);
        uint256[] memory randomWords = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            unchecked {
                randomWords[i] = (i + 1) << (test.BITS_PER_RANDOM_BATCH() * i);
            }
        }
        test.rawFulfillRandomWords(1, randomWords);
        vm.expectRevert(NoBatchesToReveal.selector);
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testRequestRandomness_PendingReveal() public {
        test.setRevealBatch(0);

        test.mintSets(7999);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                300_000,
                1 // 1 batch
            ),
            abi.encode(10)
        );
        test.requestRandomWords(bytes32(uint256(1)));
        vm.expectRevert(RevealPending.selector);
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testClearPendingReveal() public {
        test.setRevealBatch(0);

        test.mintSets(7999);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                300_000,
                1 // 1 batch
            ),
            abi.encode(10)
        );
        test.requestRandomWords(bytes32(uint256(1)));
        assertEq(test.pendingReveal(), 10);
        test.clearPendingReveal();
        assertEq(test.pendingReveal(), 0);
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testFulfillRandomnessClearsPendingReveal() public {
        test.setRevealBatch(0);

        test.mintSets(7999);
        vm.mockCall(
            address(this),
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                bytes32(uint256(1)),
                1,
                7,
                300_000,
                1 // 1 batch
            ),
            abi.encode(10)
        );
        test.requestRandomWords(bytes32(uint256(1)));

        // test.requestRandomWords(bytes32(uint256(1)));
        uint256 length = test.NUM_RANDOM_BATCHES();

        uint256[] memory randomWords = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            unchecked {
                randomWords[i] = (i + 1) << (test.BITS_PER_RANDOM_BATCH() * i);
            }
        }
        test.rawFulfillRandomWords(1, randomWords);
        assertEq(test.pendingReveal(), 0);
    }

    function testGetRandomnessForTokenId_irl() public {
        test.setPackedBatchRandomness(
            0x000000000000000000000000000000000000000000000000000000000000290d
        );
        bytes32 randomness = test.getRandomnessForTokenIdPub(0);
        assertEq(randomness, bytes32(uint256(0x290d)));
    }

    function testRawFulfillRandomWords() public {
        test.mintSets(1);
        test.setForceUnsafeReveal(true);
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1;

        randomWords[0] = 1;
        test.rawFulfillRandomWords(0, randomWords);
        bytes32 retrieved = test.packedBatchRandomness();
        assertEq(retrieved, bytes32(uint256(1)));

        test.mintSets(1000);
        randomWords[0] = 1 << 4;
        test.rawFulfillRandomWords(0, randomWords);
        retrieved = test.packedBatchRandomness();
        assertEq(retrieved, bytes32(uint256((1 << 4) | 1)));
    }
}
