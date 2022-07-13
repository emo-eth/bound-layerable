// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {BoundLayerableSnapshotImpl} from 'bound-layerable/test/BoundLayerableSnapshotImpl.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {BoundLayerableEvents} from 'bound-layerable/interface/Events.sol';
import {ArrayLengthMismatch, LayerNotBoundToTokenId, MultipleVariationsEnabled, DuplicateActiveLayers} from 'bound-layerable/interface/Errors.sol';

contract BoundLayerableSnapshotTest is Test, BoundLayerableEvents {
    BoundLayerableSnapshotImpl test;

    function setUp() public {
        test = new BoundLayerableSnapshotImpl();
        test.mint();
        test.mint();
        test.mint();
        test.setBoundLayers(14, 2**256 - 1);
        test.setPackedBatchRandomness(bytes32(uint256(2**256 - 1)));
        uint256[] memory layers = new uint256[](2);
        layers[0] = 1;
        layers[1] = 2;
        vm.startPrank(address(1));
        test.mint();
        for (uint256 i = 0; i < 7; i++) {
            test.transferFrom(address(1), address(this), i + 21);
        }
        vm.stopPrank();
    }

    function test_snapshotSetActiveLayers() public {
        test.setActiveLayers(14, ((14 << 248) | (15 << 240) | (16 << 232)));
    }

    function test_snapshotBurnAndBindMultiple1() public {
        uint256[] memory layers = new uint256[](6);
        layers[0] = 6;
        layers[1] = 1;
        layers[2] = 2;
        layers[3] = 3;
        layers[4] = 4;
        layers[5] = 5;

        test.burnAndBindMultiple(0, layers);
    }

    function test_snapshotBurnAndBindSingleTransferred() public {
        test.burnAndBindSingle(0, 22);
    }

    function test_snapshotBurnAndBindMultipleTransferred() public {
        uint256[] memory layers = new uint256[](6);
        layers[0] = 22;
        layers[1] = 23;
        layers[2] = 24;
        layers[3] = 25;
        layers[4] = 26;
        layers[5] = 27;
        test.burnAndBindMultiple(21, layers);
    }

    function test_snapshotBurnAndBindSingle() public {
        test.burnAndBindSingle(0, 1);
    }
}
