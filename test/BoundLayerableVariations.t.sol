// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {BoundLayerableVariationsTestImpl} from 'bound-layerable/test/BoundLayerableVariationsTestImpl.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {BoundLayerableEvents} from 'bound-layerable/interface/Events.sol';
import {ArrayLengthMismatch, LayerNotBoundToTokenId, MultipleVariationsEnabled, DuplicateActiveLayers} from 'bound-layerable/interface/Errors.sol';

library Helpers {
    function generateVariationMask(
        uint256 layers,
        LayerVariation memory variation
    ) internal pure returns (uint256) {
        for (
            uint256 i = variation.layerId;
            i < variation.layerId + variation.numVariations;
            i++
        ) {
            layers |= 1 << i;
        }
        return layers;
    }
}

contract BoundLayerableVariationsTest is Test, BoundLayerableEvents {
    BoundLayerableVariationsTestImpl test;

    function setUp() public {
        test = new BoundLayerableVariationsTestImpl();
        test.mint();
        test.mint();
        test.mint();
        test.setBoundLayers(14, 2**256 - 1);
        test.setTraitGenerationSeed(bytes32(bytes1(0x01)));
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

    function testCheckUnpackedIsSubsetOfBound() public {
        // pass: bound is superset of unpacked
        uint256 boundLayers = (0xFF << 248) | 2;
        uint256 unpackedLayers = 0xFF << 248;
        test.checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);

        // pass: bound is identical to unpacked
        boundLayers = 0xFF << 248;
        unpackedLayers = 0xFF << 248;
        test.checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);

        // revert: bound is subset of unpacked
        boundLayers = unpackedLayers;
        unpackedLayers |= 2;
        vm.expectRevert(LayerNotBoundToTokenId.selector);
        test.checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);

        // revert: unpacked and bound are disjoint
        boundLayers = 2;
        unpackedLayers = 0xFF << 248;
        vm.expectRevert(LayerNotBoundToTokenId.selector);
        test.checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);
    }

    function testCheckForMultipleVariations() public {
        uint256 boundLayers = 0;
        LayerVariation[] memory variations = test.getVariations();
        // pass: no variations
        boundLayers = Helpers.generateVariationMask(boundLayers, variations[0]);
        boundLayers = Helpers.generateVariationMask(0, variations[1]);
        boundLayers |= 255;
        boundLayers |= 42;

        uint256 unpackedLayers = 0;
        test.checkForMultipleVariations(boundLayers, unpackedLayers);

        // pass: one of each variation
        unpackedLayers = (1 << 200) | (1 << 4);
        test.checkForMultipleVariations(boundLayers, unpackedLayers);

        // pass: different variations
        unpackedLayers = (1 << 201) | (1 << 5);
        test.checkForMultipleVariations(boundLayers, unpackedLayers);

        // pass: variations plus other layers
        unpackedLayers = (1 << 208) | (1 << 12) | (1 << 42) | (1 << 255);
        test.checkForMultipleVariations(boundLayers, unpackedLayers);

        // revert: multiple variations
        unpackedLayers = (1 << 200) | (1 << 201) | (1 << 42) | (1 << 255);
        vm.expectRevert(MultipleVariationsEnabled.selector);
        test.checkForMultipleVariations(boundLayers, unpackedLayers);

        // revert: multiple multiple variations (same variation)
        unpackedLayers =
            (1 << 200) |
            (1 << 201) |
            (1 << 202) |
            (1 << 42) |
            (1 << 255);
        vm.expectRevert(MultipleVariationsEnabled.selector);
        test.checkForMultipleVariations(boundLayers, unpackedLayers);

        // revert: multiple multiple variations (different variations)
        unpackedLayers =
            (1 << 200) |
            (1 << 201) |
            (1 << 202) |
            (1 << 4) |
            (1 << 5) |
            (1 << 12) |
            (1 << 42) |
            (1 << 255);
        vm.expectRevert(MultipleVariationsEnabled.selector);
        test.checkForMultipleVariations(boundLayers, unpackedLayers);
    }

    function testUnpackLayersToBitMapAndCheckForDuplicates() public {
        uint256[] memory layers = new uint256[](4);
        layers[0] = 1;
        layers[1] = 2;
        layers[2] = 3;
        layers[3] = 4;
        uint256 packedLayers = PackedByteUtility.packArrayOfBytes(layers);

        // // pass: < 32 length no duplicates
        test.unpackLayersToBitMapAndCheckForDuplicates(packedLayers);

        layers = new uint256[](33);
        for (uint256 i; i < layers.length; ++i) {
            layers[i] = uint256(i + 1);
        }
        // // pass: > 32 length no duplicates
        test.unpackLayersToBitMapAndCheckForDuplicates(
            PackedByteUtility.packArrayOfBytes(layers)
        );

        // fail: 32 length; last duplicate
        layers = new uint256[](32);
        for (uint256 i; i < layers.length; ++i) {
            layers[i] = uint256(i + 1);
        }
        layers[31] = layers[30];
        packedLayers = PackedByteUtility.packArrayOfBytes(layers);

        vm.expectRevert(DuplicateActiveLayers.selector);
        test.unpackLayersToBitMapAndCheckForDuplicates(packedLayers);

        // // fail: 33 length; duplicate on uint in array
        // layers = new uint256[](33);
        // for (uint256 i; i < layers.length; ++i) {
        //     layers[i] = uint256(i + 5);
        // }
        // layers[32] = layers[31];
        // packedLayers = PackedByteUtility.packArrayOfBytes(layers);
        // vm.expectRevert(DuplicateActiveLayers.selector);
        // test.unpackLayersToBitMapAndCheckForDuplicates(packedLayers);
    }

    function testSetActiveLayers() public {
        uint256 boundLayers = 0;
        LayerVariation[] memory variations = test.getVariations();
        boundLayers = Helpers.generateVariationMask(boundLayers, variations[0]);
        boundLayers = Helpers.generateVariationMask(boundLayers, variations[1]);
        boundLayers |= 1 << 255;
        boundLayers |= 1 << 42;
        test.setBoundLayers(0, boundLayers);
        uint256[] memory layers = new uint256[](4);
        layers[0] = 42;
        layers[1] = 255;
        layers[2] = 4;
        layers[3] = 200;
        uint256 activeLayers = PackedByteUtility.packArrayOfBytes(layers);
        test.setActiveLayers(0, activeLayers);

        assertEq(test.getActiveLayersRaw(0), activeLayers);
    }

    // todo: skip, need way to allocate memory
    function testGetActiveLayers() public {
        test.removeVariations();
        uint256 boundlayers = 2**256 - 1;
        test.setBoundLayers(0, boundlayers);
        uint256[] memory layers = new uint256[](32);
        for (uint256 i; i < layers.length; ++i) {
            layers[i] = uint256(i + 1);
        }
        uint256 packedLayers = PackedByteUtility.packArrayOfBytes(layers);
        test.setActiveLayers(0, packedLayers);
        uint256[] memory activeLayers = test.getActiveLayers(0);
        emit log_named_uint('activeLayers.length', activeLayers.length);
        // emit log_named_uint("activeLayers[255]", activeLayers[255]);
        assertEq(activeLayers.length, 32);
        for (uint256 i; i < activeLayers.length; ++i) {
            assertEq(activeLayers[i], i + 1);
        }
    }

    function testGetActiveLayersNoLayers() public view {
        test.getActiveLayers(0);
    }

    function testBurnAndBindSingle() public {
        vm.expectEmit(true, true, false, false, address(test));
        emit LayersBoundToToken(7, (1 << 8) | (1 << 9));
        test.burnAndBindSingle(7, 8);
        assertTrue(test.isBurned(8));
        assertFalse(test.isBurned(7));

        uint256[] memory boundLayers = test.getBoundLayers(7);
        assertEq(boundLayers.length, 2);
        assertEq(boundLayers[0], 8);
        assertEq(boundLayers[1], 9);
        // test bind unowned layer to owned
    }

    function test_snapshotBurnAndBindMultiple() public {
        uint256[] memory layers = new uint256[](6);
        layers[0] = 1;
        layers[1] = 6;
        layers[2] = 2;
        layers[3] = 3;
        layers[4] = 4;
        layers[5] = 5;

        test.burnAndBindMultiple(0, layers);
    }

    function test_snapshotBurnAndBindSingleTransferred() public {
        test.burnAndBindSingle(7, 22);
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

    function testBurnAndBindMultiple() public {
        uint256[] memory layers = new uint256[](2);
        layers[0] = 1;
        layers[1] = 2;
        vm.expectEmit(true, true, false, false, address(test));
        emit LayersBoundToToken(7, (1 << 2) | (1 << 3) | (1 << 8));
        test.burnAndBindMultiple(7, layers);
        assertTrue(test.isBurned(1));
        assertTrue(test.isBurned(2));
        assertFalse(test.isBurned(7));
        uint256 bindings = test.getBoundLayerBitMap(7);
        emit log_named_uint('bindings', bindings);
        uint256[] memory boundLayers = test.getBoundLayers(7);
        assertEq(boundLayers.length, 3);
        assertEq(boundLayers[0], 2);
        assertEq(boundLayers[1], 3);
        assertEq(boundLayers[2], 8);
    }

    function test_snapshotBurnAndBindSingle() public {
        test.burnAndBindSingle(7, 1);
    }
}
