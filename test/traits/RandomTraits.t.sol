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

    function setPackedBatchRandomness(bytes32 seed) public {
        packedBatchRandomness = seed;
    }

    function getLayerTypeDistributions(uint8 layerType)
        public
        view
        returns (uint256[2] memory)
    {
        return layerTypeToPackedDistributions[layerType];
    }

    function getLayerSeedPub(
        uint256 tokenId,
        uint8 layerType,
        bytes32 seed
    ) public pure returns (uint16) {
        return getLayerSeed(tokenId, layerType, seed);
    }

    function getLayerIdPub(
        uint8 layerType,
        uint256 layerSeed,
        uint256[2] memory distributions
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

    function testSetLayerTypeDistribution(
        uint8 layerType,
        uint256[2] memory distribution
    ) public {
        layerType = uint8(bound(layerType, 0, 7));
        test.setLayerTypeDistribution(layerType, distribution);
        assertEq(
            keccak256(abi.encode(test.getLayerTypeDistributions(layerType))),
            keccak256(abi.encode(distribution))
        );
    }

    function testSetLayerTypeDistributionInvalidLayerType(uint8 layerType)
        public
    {
        layerType = uint8(bound(layerType, 8, 255));
        vm.expectRevert(abi.encodeWithSelector(InvalidLayerType.selector));
        uint256[2] memory _distributions = [uint256(0), uint256(0)];
        test.setLayerTypeDistribution(layerType, _distributions);
    }

    function testSetLayerTypeDistributionNotOwner(address notOwner) public {
        vm.assume(notOwner != address(this));
        vm.startPrank(notOwner);
        uint256[2] memory _distributions = [uint256(1), uint256(0)];

        vm.expectRevert('Ownable: caller is not the owner');
        test.setLayerTypeDistribution(0, _distributions);
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

    function testGetLayerIdBounds(uint32 packedBatchRandomness) public {
        vm.assume(packedBatchRandomness != 0);
        test.setPackedBatchRandomness(bytes32(uint256(packedBatchRandomness)));
        distributions.push(0x80);
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            PackedByteUtility.packArrayOfShorts(distributions)
        );
        uint256 layerId = test.getLayerId(0);
        assertTrue(layerId == 1 || layerId == 2);
    }

    function testGetLayerIdBounds(
        uint32 packedBatchRandomness,
        uint8 numDistributions
    ) public {
        vm.assume(packedBatchRandomness != 0);
        test.setPackedBatchRandomness(bytes32(uint256(packedBatchRandomness)));

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
            PackedByteUtility.packArrayOfShorts(distributions)
        );
        uint256 layerId = test.getLayerId(0);
        assertGt(layerId, 0);
        assertLt(layerId, 33);
    }

    function testGetLayerIdBoundsDirect(
        uint16 layerSeed,
        uint8 layerType,
        uint8 numDistributions,
        uint16 increment
    ) public {
        layerType = uint8(bound(layerType, 0, 7));
        numDistributions = uint8(bound(numDistributions, 1, 32));
        increment = uint16(bound(increment, 1, 2048));

        for (uint256 i = 0; i < numDistributions; ++i) {
            // ~ evenly split distributions
            uint256 num = (i + 1) * increment;
            if (num == 65536) {
                num == 65535;
            }
            distributions.push(num);
        }
        uint256[2] memory distributionPacked = PackedByteUtility
            .packArrayOfShorts(distributions);
        emit log_named_uint('distributions[0]', distributionPacked[0]);
        emit log_named_uint('distributions[1]', distributionPacked[1]);

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

    // function testNDistributionsForNMaxNot255() public {
    //     uint256 numDistributions = test.getNumDistributionsForNMax(255);
    //     assertEq(numDistributions, 0);
    // }
}
