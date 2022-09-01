// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {BoundLayerableTestImpl} from 'bound-layerable/implementations/BoundLayerableTestImpl.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {BoundLayerableEvents} from 'bound-layerable/interface/Events.sol';
import {ArrayLengthMismatch, LayerAlreadyBound, NotOwner, OnlyBase, CannotBindBase, LayerNotBoundToTokenId, MultipleVariationsEnabled, DuplicateActiveLayers, NoActiveLayers} from 'bound-layerable/interface/Errors.sol';
import {MAX_INT} from 'bound-layerable/interface/Constants.sol';
import {ILayerable} from 'bound-layerable/metadata/ILayerable.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';

contract MockLayerable {
    function getTokenURI(
        uint256,
        uint256,
        uint256,
        uint256[] calldata,
        bytes32
    ) public pure returns (string memory) {
        return 'MockLayerable';
    }
}

contract BoundLayerableTest is Test, BoundLayerableEvents {
    BoundLayerableTestImpl test;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function setUp() public {
        test = new BoundLayerableTestImpl();
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

    function testSetMetadataContract() public {
        ILayerable layerable = new ImageLayerable(
            msg.sender,
            'default',
            100,
            100,
            'external',
            'description'
        );
        test.setMetadataContract(layerable);
        assertEq(address(test.metadataContract()), address(layerable));
    }

    function testSetMetadataContract_onlyOwner(address addr) public {
        vm.assume(addr != address(this));
        ILayerable layerable = new ImageLayerable(
            msg.sender,
            'default',
            100,
            100,
            'external',
            'description'
        );
        vm.startPrank(addr);
        vm.expectRevert(0x5fc483c5);
        test.setMetadataContract(layerable);
    }

    function testCheckUnpackedIsSubsetOfBound1() public {
        // pass: bound is superset of unpacked
        uint256 boundLayers = (0xFF << 248) | 2;
        uint256 unpackedLayers = 0xFF << 248;
        test.checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);

        // pass: bound is identical to unpacked
        boundLayers = 0xFF << 248;
        unpackedLayers = 0xFF << 248;
        test.checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);

        // revert: bound is subset of unpacked
        boundLayers = 0xFF << 248;
        unpackedLayers |= 2;
        vm.expectRevert(
            abi.encodeWithSelector(LayerNotBoundToTokenId.selector, 2)
        );
        test.checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);

        // revert: unpacked and bound are disjoint
        boundLayers = 2;
        unpackedLayers = 0xFF << 248;
        vm.expectRevert(
            abi.encodeWithSelector(LayerNotBoundToTokenId.selector, 0xFF << 248)
        );
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

        // fail: 32 length; first duplicate of last
        layers = new uint256[](32);
        for (uint256 i; i < layers.length; ++i) {
            layers[i] = uint256(i + 1);
        }
        layers[0] = layers[31];
        packedLayers = PackedByteUtility.packArrayOfBytes(layers);

        vm.expectRevert(DuplicateActiveLayers.selector);
        test.unpackLayersToBitMapAndCheckForDuplicates(packedLayers);

        // fail: 32 length; first duplicate of middle
        layers = new uint256[](32);
        for (uint256 i; i < layers.length; ++i) {
            layers[i] = uint256(i + 1);
        }
        layers[0] = layers[15];
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
        vm.expectEmit(true, true, true, false, address(test));
        emit ActiveLayersChanged(address(this), 0, activeLayers);
        test.setActiveLayers(0, activeLayers);

        assertEq(test.getActiveLayersRaw(0), activeLayers);
    }

    function testSetActiveLayers_NotOwner() public {
        vm.prank(address(1));
        test.mint();

        uint256 boundLayers = 1 << 42;
        test.setBoundLayers(0, boundLayers);
        uint256[] memory layers = new uint256[](1);
        layers[0] = 42;
        uint256 activeLayers = PackedByteUtility.packArrayOfBytes(layers);

        vm.expectRevert(NotOwner.selector);
        test.setActiveLayers(28, activeLayers);
    }

    function testSetActiveLayers_OnlyBase() public {
        uint256 boundLayers = 1 << 42;
        test.setBoundLayers(8, boundLayers);
        uint256[] memory layers = new uint256[](1);
        layers[0] = 42;
        uint256 activeLayers = PackedByteUtility.packArrayOfBytes(layers);

        vm.expectRevert(OnlyBase.selector);
        test.setActiveLayers(8, activeLayers);
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
        assertEq(activeLayers.length, 32);
        for (uint256 i; i < activeLayers.length; ++i) {
            assertEq(activeLayers[i], i + 1);
        }
    }

    function testGetActiveLayersNoLayers() public {
        uint256[] memory layers = test.getActiveLayers(0);
        assertEq(layers.length, 0);
    }

    function testGetActiveLayers(uint8 numActiveLayers) public {
        numActiveLayers = uint8(bound(numActiveLayers, 0, 32));
        uint256 bindings;
        uint256[] memory layers = new uint256[](numActiveLayers);
        for (uint256 i; i < numActiveLayers; ++i) {
            layers[i] = i + 1;
            bindings |= 1 << (i + 1);
        }

        uint256 packed = PackedByteUtility.packArrayOfBytes(layers);
        test.setBoundLayers(0, bindings);
        if (numActiveLayers == 0) {
            vm.expectRevert(NoActiveLayers.selector);
            test.setActiveLayers(0, packed);
        } else {
            test.setActiveLayers(0, packed);
            test.setActiveLayers(0, packed);
            uint256[] memory loaded = test.getActiveLayers(0);
            assertEq(loaded.length, numActiveLayers);
            for (uint256 i; i < loaded.length; ++i) {
                assertEq(loaded[i], layers[i]);
            }
        }
    }

    function testgetBoundLayers(uint8 numBoundLayers) public {
        numBoundLayers = uint8(bound(numBoundLayers, 1, 255));
        uint256 bindings;
        for (uint256 i; i < numBoundLayers - 1; ++i) {
            bindings |= 1 << (i + 1);
        }

        test.setBoundLayers(0, bindings);
        uint256[] memory loaded = test.getBoundLayers(0);
        assertEq(loaded.length, numBoundLayers - 1);
        for (uint256 i; i < loaded.length; ++i) {
            assertEq(loaded[i], i + 1);
        }

        for (uint256 i; i < numBoundLayers; ++i) {
            bindings |= 1 << (i + 1);
        }

        test.setBoundLayers(7, bindings);
        loaded = test.getBoundLayers(7);
        assertEq(loaded.length, numBoundLayers);
        for (uint256 i; i < loaded.length; ++i) {
            assertEq(loaded[i], i + 1);
        }
    }

    function testBurnAndBindSingle() public {
        test.setPackedBatchRandomness(bytes32(MAX_INT));
        vm.expectEmit(true, true, true, false, address(test));
        emit Transfer(address(this), address(0), 8);
        vm.expectEmit(true, true, false, false, address(test));
        emit LayersBoundToToken(address(this), 7, (1 << 8) | (1 << 9));

        test.burnAndBindSingle(7, 8);
        assertTrue(test.isBurned(8));
        assertFalse(test.isBurned(7));

        uint256[] memory boundLayers = test.getBoundLayers(7);
        assertEq(boundLayers.length, 2);
        assertEq(boundLayers[0], 8);
        assertEq(boundLayers[1], 9);
        // TODO: test bind unowned layer to owned, all restrictions
    }

    function testBurnAndBindSingleAndSetActiveLayers() public {
        test.setPackedBatchRandomness(bytes32(MAX_INT));
        vm.expectEmit(true, true, true, false, address(test));
        emit Transfer(address(this), address(0), 8);
        vm.expectEmit(true, true, false, false, address(test));
        emit LayersBoundToToken(address(this), 7, (1 << 8) | (1 << 9));
        vm.expectEmit(true, true, false, false, address(test));
        emit ActiveLayersChanged(address(this), 7, 8 << 248);

        test.burnAndBindSingleAndSetActiveLayers(7, 8, 8 << 248);
        assertTrue(test.isBurned(8));
        assertFalse(test.isBurned(7));

        uint256[] memory boundLayers = test.getBoundLayers(7);
        assertEq(boundLayers.length, 2);
        assertEq(boundLayers[0], 8);
        assertEq(boundLayers[1], 9);
    }

    function testBurnAndBindMultiple() public {
        uint256[] memory layers = new uint256[](2);
        layers[0] = 1;
        layers[1] = 6;
        vm.expectEmit(true, true, true, false, address(test));
        emit Transfer(address(this), address(0), 1);
        vm.expectEmit(true, true, true, false, address(test));
        emit Transfer(address(this), address(0), 6);
        vm.expectEmit(true, true, false, false, address(test));
        emit LayersBoundToToken(
            address(this),
            0,
            (1 << 1) | (1 << 2) | (1 << 7)
        );

        test.burnAndBindMultiple(0, layers);
        assertTrue(test.isBurned(6));
        assertTrue(test.isBurned(1));
        assertFalse(test.isBurned(0));
        uint256[] memory boundLayers = test.getBoundLayers(0);
        assertEq(boundLayers.length, 3);
        assertEq(boundLayers[0], 1);
        assertEq(boundLayers[1], 2);
        assertEq(boundLayers[2], 7);
    }

    function testBurnAndBindMultipleAndSetActiveLayers() public {
        uint256[] memory layers = new uint256[](2);
        layers[0] = 1;
        layers[1] = 6;
        vm.expectEmit(true, true, true, false, address(test));
        emit Transfer(address(this), address(0), 1);
        vm.expectEmit(true, true, true, false, address(test));
        emit Transfer(address(this), address(0), 6);
        vm.expectEmit(true, true, false, false, address(test));
        emit LayersBoundToToken(
            address(this),
            0,
            (1 << 1) | (1 << 2) | (1 << 7)
        );
        vm.expectEmit(true, true, false, false, address(test));
        emit ActiveLayersChanged(address(this), 0, 7 << 248);

        test.burnAndBindMultipleAndSetActiveLayers(0, layers, 7 << 248);
        assertTrue(test.isBurned(6));
        assertTrue(test.isBurned(1));
        assertFalse(test.isBurned(0));
        uint256[] memory boundLayers = test.getBoundLayers(0);
        assertEq(boundLayers.length, 3);
        assertEq(boundLayers[0], 1);
        assertEq(boundLayers[1], 2);
        assertEq(boundLayers[2], 7);
    }

    function testBurnAndBindSingle_NotOwner() public {
        // create tokens not owned by address(this)
        vm.prank(address(1));
        test.mint();

        // not owner of layer
        vm.expectRevert(NotOwner.selector);
        test.burnAndBindSingle(7, 29);
        // not owner of base
        vm.expectRevert(NotOwner.selector);
        test.burnAndBindSingle(28, 8);
    }

    function testBurnAndBindSingle_LayerAlreadyBound() public {
        test.setBoundLayers(0, 1 << 9);
        vm.expectRevert(LayerAlreadyBound.selector);
        test.burnAndBindSingle(0, 8);
    }

    function testBurnAndBindSingle_OnlyBase() public {
        vm.expectRevert(OnlyBase.selector);
        test.burnAndBindSingle(8, 1);
    }

    function testBurnAndBindSingle_CannotBindBase() public {
        vm.expectRevert(CannotBindBase.selector);
        test.burnAndBindSingle(7, 0);
    }

    function testBurnAndBindSingleBatchNotRevealed() public {
        test.setPackedBatchRandomness(bytes32(uint256(0)));
        vm.expectRevert(abi.encodeWithSignature('BatchNotRevealed()'));
        test.burnAndBindSingle(0, 6);
    }

    function testBurnAndBindMultiple_NotOwner() public {
        // create tokens not owned by address(this)
        vm.prank(address(1));
        test.mint();

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 29;

        // not owner of layer
        vm.expectRevert(NotOwner.selector);
        test.burnAndBindMultiple(7, tokenIds);
        // not owner of base
        tokenIds[0] = 8;
        vm.expectRevert(NotOwner.selector);
        test.burnAndBindMultiple(28, tokenIds);
    }

    function testBurnAndBindMultiple_OnlyBase() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        vm.expectRevert(OnlyBase.selector);
        test.burnAndBindMultiple(8, tokenIds);
    }

    function testBurnAndBindMultiple_CannotBindBase() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        vm.expectRevert(CannotBindBase.selector);
        test.burnAndBindMultiple(7, tokenIds);
    }

    function testBurnAndBindMultiple_LayerAlreadyBound() public {
        test.setBoundLayers(0, 1 << 9);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 8;
        vm.expectRevert(LayerAlreadyBound.selector);
        test.burnAndBindMultiple(0, tokenIds);
    }

    function testBurnAndBindMultipleBatchNotRevealed() public {
        uint256[] memory layers = new uint256[](2);
        layers[0] = 1;
        layers[1] = 2;
        test.setPackedBatchRandomness(bytes32(uint256(0)));
        vm.expectRevert(abi.encodeWithSignature('BatchNotRevealed()'));
        test.burnAndBindMultiple(7, layers);
    }

    function testGetTokenURI() public {
        ILayerable mock = ILayerable(address(new MockLayerable()));
        test.setMetadataContract(mock);
        string memory uri = test.getTokenURI(0);
        assertEq(uri, 'MockLayerable');
    }
}
