// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';

import {BatchVRFConsumer} from 'bound-layerable/vrf/BatchVRFConsumer.sol';
import {ERC20} from 'solmate/tokens/ERC20.sol';
import {VRFCoordinatorV2Interface} from 'chainlink/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';

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

    function mintSets(uint256 numSets) public {
        setNextTokenIdWithBatch(numSets);
    }

    function setRevealBatch(uint256 batch) public {
        revealBatch = batch;
    }

    function nextTokenId() internal virtual override returns (uint256) {
        return fakeNextTokenId;
    }

    function setNextTokenIdWithBatch(uint256 numSets) public {
        fakeNextTokenId = numSets * uint256(NUM_TOKENS_PER_SET);
    }
}

contract BatchVRFConsumerTest is Test {
    BatchVRFConsumerImpl test;

    function setUp() public {
        test = new BatchVRFConsumerImpl(
            'test',
            'test',
            address(this),
            5555,
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

    function testRequestRandomWords() public {
        test.mintSets(uint256(5555) / 8 + 1);
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

        uint256 numSets = (uint256(5555) * completedBatches) / 8 + 1;
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
        test.mintSets(5555);
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
        test.mintSets(5555);
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
        test.mintSets((uint256(5555) * 3) / 8 + 1);
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
        test.mintSets((uint256(5555) * 3) / 8 + 1);
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
        test.setForceUnsafeReveal(true);
        test.requestRandomWords(bytes32(uint256(1)));
    }

    function testRequestMaxRandomness() public {
        test.mintSets(5555);
        test.setRevealBatch(8);
        vm.expectRevert(abi.encodeWithSignature('MaxRandomness()'));
        test.requestRandomWords(bytes32(uint256(1)));
    }
}
