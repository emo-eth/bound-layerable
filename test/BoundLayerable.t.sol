// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {BoundLayerableTestImpl} from 'bound-layerable/test/BoundLayerableTestImpl.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {BoundLayerableEvents} from 'bound-layerable/interface/Events.sol';
import {ArrayLengthMismatch, LayerNotBoundToTokenId, MultipleVariationsEnabled, DuplicateActiveLayers} from 'bound-layerable/interface/Errors.sol';
import {MAX_INT} from 'bound-layerable/interface/Constants.sol';
import {ILayerable} from 'bound-layerable/metadata/ILayerable.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';

contract BoundLayerableTest is Test, BoundLayerableEvents {
    BoundLayerableTestImpl test;

    function setUp() public {
        test = new BoundLayerableTestImpl();
        test.mint();
        test.mint();
        test.mint();
        test.setBoundLayers(14, 2**256 - 1);
        test.setTraitGenerationSeed(bytes32(uint256(2**256 - 1)));
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

    function testSetMetadataContract() public {
        ILayerable layerable = new ImageLayerable('default', msg.sender);
        test.setMetadataContract(layerable);
        assertEq(address(test.metadataContract()), address(layerable));
    }

    function testSetMetadataContract_onlyOwner(address addr) public {
        vm.assume(addr != address(this));
        ILayerable layerable = new ImageLayerable('default', msg.sender);
        vm.startPrank(addr);
        vm.expectRevert('Ownable: caller is not the owner');
        test.setMetadataContract(layerable);
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
    }

    function testSetActiveLayers() public {
        uint256 boundLayers = 0;
        boundLayers |= 1 << 200;
        boundLayers |= 1 << 4;
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

    function testGetActiveLayers() public {
        // test.removeVariations();
        uint256 boundlayers = 2**256 - 1;
        test.setBoundLayers(0, boundlayers);
        uint256[] memory layers = new uint256[](32);
        for (uint256 i; i < layers.length; ++i) {
            layers[i] = uint256(i + 1);
        }
        uint256 packedLayers = PackedByteUtility.packArrayOfBytes(layers);
        test.setActiveLayers(0, packedLayers);
        uint256[] memory activeLayers = test.getActiveLayers(0);
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
        test.setTraitGenerationSeed(bytes32(MAX_INT));
        vm.expectEmit(true, true, false, false, address(test));
        emit LayersBoundToToken(7, (1 << 8) | (1 << 9));
        test.burnAndBindSingle(7, 8);
        assertTrue(test.isBurned(8));
        assertFalse(test.isBurned(7));

        uint256[] memory boundLayers = test.getBoundLayers(7);
        assertEq(boundLayers.length, 2);
        assertEq(boundLayers[0], 8);
        assertEq(boundLayers[1], 9);
        // TODO: test bind unowned layer to owned, all restrictions
    }

    function testBurnAndBindMultiple() public {
        uint256[] memory layers = new uint256[](2);
        layers[0] = 1;
        layers[1] = 6;
        vm.expectEmit(true, true, false, false, address(test));
        emit LayersBoundToToken(0, (1 << 1) | (1 << 2) | (1 << 7));
        test.burnAndBindMultiple(0, layers);
        assertTrue(test.isBurned(6));
        assertTrue(test.isBurned(1));
        assertFalse(test.isBurned(0));
        uint256 bindings = test.getBoundLayerBitMap(0);
        emit log_named_uint('bindings', bindings);
        uint256[] memory boundLayers = test.getBoundLayers(0);
        assertEq(boundLayers.length, 3);
        assertEq(boundLayers[0], 1);
        assertEq(boundLayers[1], 2);
        assertEq(boundLayers[2], 7);
    }

    function testBurnAndBindSingleBatchNotRevealed() public {
        test.setTraitGenerationSeed(bytes32(uint256(0)));
        vm.expectRevert(abi.encodeWithSignature('BatchNotRevealed()'));
        test.burnAndBindSingle(6, 7);
    }

    function testBurnAndBindMultipleBatchNotRevealed() public {
        uint256[] memory layers = new uint256[](2);
        layers[0] = 1;
        layers[1] = 2;
        test.setTraitGenerationSeed(bytes32(uint256(0)));
        vm.expectRevert(abi.encodeWithSignature('BatchNotRevealed()'));
        test.burnAndBindMultiple(7, layers);
    }
}
