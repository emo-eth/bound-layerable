// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {BoundLayerableTestImpl} from 'bound-layerable/test/BoundLayerableTestImpl.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {BoundLayerableEvents} from 'bound-layerable/interface/Events.sol';
import {ArrayLengthMismatch, LayerNotBoundToTokenId, MultipleVariationsEnabled, DuplicateActiveLayers} from 'bound-layerable/interface/Errors.sol';

contract BoundLayerableFuzzTest is Test, BoundLayerableEvents {
    BoundLayerableTestImpl test;

    function setUp() public {
        test = new BoundLayerableTestImpl();
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

    function testFuzzCheckUnpackedIsSubsetOfBound(
        uint256 superset,
        uint256 subset
    ) public {
        // create perfect superset
        uint256 originalSuperset = superset;
        superset |= subset;
        // check should not revert
        test.checkUnpackedIsSubsetOfBound(subset, superset);

        // create bad superset
        uint256 badSuperSet = originalSuperset &= subset;
        // if they're equal, add 1 bit to subset
        // unless not possible, in which case, swap the two and subtract 1 bit from badsuper
        if (badSuperSet == subset) {
            if (subset != type(uint256).max) {
                subset += 1;
            } else {
                badSuperSet = subset - 1;
            }
        }
        // check should revert
        vm.expectRevert(
            abi.encodeWithSelector(LayerNotBoundToTokenId.selector)
        );
        test.checkUnpackedIsSubsetOfBound(subset, badSuperSet);
    }
}
