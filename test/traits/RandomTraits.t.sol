// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraitsImpl} from 'bound-layerable/traits/RandomTraitsImpl.sol';
import {BadDistributions, InvalidLayerType} from 'bound-layerable/interface/Errors.sol';

contract RandomTraitsTestImpl is RandomTraitsImpl {
    constructor(uint8 numTokensPerSet)
        RandomTraits('', '', address(1234), 5555, numTokensPerSet, 1)
    {}

    function setTraitGenerationSeed(bytes32 seed) public {
        traitGenerationSeed = seed;
    }

    function getLayerTypeDistributions(uint8 layerType)
        public
        view
        returns (uint256)
    {
        return layerTypeToPackedDistributions[layerType];
    }

    function getLayerSeedPub(
        uint256 tokenId,
        uint8 layerType,
        bytes32 seed
    ) public pure returns (uint8) {
        return getLayerSeed(tokenId, layerType, seed);
    }

    function getLayerIdPub(
        uint8 layerType,
        uint256 layerSeed,
        uint256 distributions
    ) public pure returns (uint256) {
        return getLayerId(layerType, layerSeed, distributions);
    }
}

contract RandomTraitsTest is Test {
    RandomTraitsTestImpl test;
    uint256[] distributions;

    function setUp() public {
        test = new RandomTraitsTestImpl(7);
    }

    function testSetLayerTypeDistribution(uint8 layerType, uint256 distribution)
        public
    {
        layerType = uint8(bound(layerType, 0, 7));
        test.setLayerTypeDistribution(layerType, distribution);
        assertEq(test.getLayerTypeDistributions(layerType), distribution);
    }

    function testSetLayerTypeDistributionInvalidLayerType(uint8 layerType)
        public
    {
        layerType = uint8(bound(layerType, 8, 255));
        vm.expectRevert(abi.encodeWithSelector(InvalidLayerType.selector));
        test.setLayerTypeDistribution(layerType, 0);
    }

    function testSetLayerTypeDistributionNotOwner(address notOwner) public {
        vm.assume(notOwner != address(this));
        vm.startPrank(notOwner);
        vm.expectRevert('Ownable: caller is not the owner');
        test.setLayerTypeDistribution(0, 1);
    }

    function testGetLayerSeedShifts() public {
        uint256 validTokenId = 1;
        // test that we are correctly packing values by providing a tokenId that will be truncated to 248 bits
        uint256 truncatedTokenId = 2**248 + 1;
        bytes32 seed = bytes32(uint256(1));
        bytes32 seed2 = bytes32(uint256(2));
        uint8 layerType = 1;
        uint8 layerType2 = 2;

        assertEq(
            test.getLayerSeedPub(truncatedTokenId, layerType, seed),
            test.getLayerSeedPub(validTokenId, layerType, seed)
        );
        assertFalse(
            test.getLayerSeedPub(truncatedTokenId, layerType, seed) ==
                test.getLayerSeedPub(validTokenId, layerType, seed2)
        );
        assertFalse(
            test.getLayerSeedPub(truncatedTokenId, layerType, seed) ==
                test.getLayerSeedPub(validTokenId, layerType2, seed)
        );
    }

    function testGetLayerIdBounds(uint32 traitGenerationSeed) public {
        vm.assume(traitGenerationSeed != 0);
        test.setTraitGenerationSeed(bytes32(uint256(traitGenerationSeed)));
        distributions.push(0x80);
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            PackedByteUtility.packArrayOfBytes(distributions)
        );
        uint256 layerId = test.getLayerId(0);
        assertTrue(layerId == 1 || layerId == 2);
    }

    function testGetLayerIdBounds(
        uint32 traitGenerationSeed,
        uint8 numDistributions
    ) public {
        vm.assume(traitGenerationSeed != 0);
        test.setTraitGenerationSeed(bytes32(uint256(traitGenerationSeed)));

        numDistributions = uint8(bound(numDistributions, 1, 32));
        for (uint256 i = 0; i < numDistributions; ++i) {
            // ~ evenly split distributions
            uint256 num = (i + 1) * 8;
            if (num == 256) {
                num == 255;
            }
            distributions.push(num);
        }
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            PackedByteUtility.packArrayOfBytes(distributions)
        );
        uint256 layerId = test.getLayerId(0);
        assertGt(layerId, 0);
        assertLt(layerId, 33);
    }

    function testGetLayerIdBoundsDirect(
        uint8 layerSeed,
        uint8 layerType,
        uint8 numDistributions,
        uint8 increment
    ) public {
        layerType = uint8(bound(layerType, 0, 7));
        numDistributions = uint8(bound(numDistributions, 1, 32));
        increment = uint8(bound(increment, 1, 8));

        for (uint256 i = 0; i < numDistributions; ++i) {
            // ~ evenly split distributions
            uint256 num = (i + 1) * increment;
            if (num == 256) {
                num == 255;
            }
            distributions.push(num);
        }
        uint256 distributionPacked = PackedByteUtility.packArrayOfBytes(
            distributions
        );

        // test will revert if it's the last layer type and ends at an index higher than 31
        // since it will try to assign layerId to 256
        bool willRevert = layerType == 7 &&
            numDistributions > 30 &&
            // if gte this value, will be assigned to index 32 and overflow
            layerSeed >= 31 * uint256(increment);
        uint256 layerId;
        if (willRevert) {
            vm.expectRevert(abi.encodeWithSelector(BadDistributions.selector));
            test.getLayerIdPub(
                layerType,
                uint256(layerSeed),
                distributionPacked
            );
        } else {
            layerId = test.getLayerIdPub(
                layerType,
                uint256(layerSeed),
                distributionPacked
            );

            uint256 layerTypeOffset = uint256(layerType) * 32;
            assertGt(layerId, 0 + layerTypeOffset);
            assertLt(layerId, 33 + layerTypeOffset);
            assertLt(layerId, 256);

            uint256 bin = uint256(layerSeed) / uint256(increment) + 1;
            if (bin > numDistributions) {
                if (numDistributions == 32) {
                    bin = 32;
                } else {
                    bin = numDistributions + 1;
                }
            }
            assertEq(layerId, bin + layerTypeOffset);
        }
    }

    function testGetLayerType() public {
        distributions = new uint256[](0);
        // % 7 == 0 should be portrait
        assertEq(uint256(test.getLayerType(0)), 0);
        assertEq(uint256(test.getLayerType(7)), 0);

        // % 7 == 1 should be background
        assertEq(uint256(test.getLayerType(1)), 1);
        assertEq(uint256(test.getLayerType(8)), 1);

        // % 7 == 2 should be texture
        assertEq(uint256(test.getLayerType(2)), 2);
        assertEq(uint256(test.getLayerType(9)), 2);

        // % 7 == 3 should be object
        assertEq(uint256(test.getLayerType(3)), 3);
        assertEq(uint256(test.getLayerType(10)), 3);

        // % 7 == 4 should be object2
        assertEq(uint256(test.getLayerType(4)), 4);
        assertEq(uint256(test.getLayerType(11)), 4);

        // % 7 == 5 should be border
        assertEq(uint256(test.getLayerType(5)), 5);
        assertEq(uint256(test.getLayerType(12)), 5);

        // % 7 == 6 should be border
        assertEq(uint256(test.getLayerType(6)), 5);
        assertEq(uint256(test.getLayerType(13)), 5);
    }
}
