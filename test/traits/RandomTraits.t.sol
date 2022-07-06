// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraitsImpl} from 'bound-layerable/traits/RandomTraitsImpl.sol';
import {BadDistributions, TraitGenerationSeedNotSet, InvalidLayerType} from 'bound-layerable/interface/Errors.sol';

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

    function testGetLayerIdBounds(bytes32 traitGenerationSeed) public {
        vm.assume(traitGenerationSeed != 0);
        test.setTraitGenerationSeed(traitGenerationSeed);
        distributions.push(0x80);
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            PackedByteUtility.packArrayOfBytes(distributions)
        );
        uint256 layerId = test.getLayerId(0);
        assertTrue(layerId == 1 || layerId == 2);
    }

    function testGetLayerIdBounds(
        bytes32 traitGenerationSeed,
        uint8 numDistributions
    ) public {
        vm.assume(traitGenerationSeed != 0);
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
        uint8 numDistributions
    ) public {
        layerType = uint8(bound(layerType, 0, 7));
        numDistributions = uint8(bound(numDistributions, 1, 32));
        emit log_named_uint('layerSeed', layerSeed);
        emit log_named_uint('layerType', layerType);
        emit log_named_uint('numDistributions', numDistributions);
        for (uint256 i = 0; i < numDistributions; ++i) {
            // ~ evenly split distributions
            uint256 num = (i + 1) * 8;
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
            layerSeed >= 248;

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

    // function testGetLayerId() public {
    //     test.setTraitGenerationSeed(bytes32(uint256(42)));
    //     emit log_named_bytes32('seed', test.traitGenerationSeed());
    //     // first byte is 0x64, or 0b01100100
    //     emit log_named_bytes32(
    //         'hash 1',
    //         keccak256(
    //             abi.encode(
    //                 test.traitGenerationSeed(),
    //                 uint256(1),
    //                 uint8(LayerType.BACKGROUND)
    //             )
    //         )
    //     );
    //     // less than first distribution
    //     distributions = new uint256[](0);
    //     distributions.push(0x80);
    //     distributions.push(0xc0);
    //     test.setLayerTypeDistribution(
    //         uint8(LayerType.PORTRAIT),
    //         PackedByteUtility.packArrayOfBytes(distributions)
    //     );
    //     uint256 layerId = test.getLayerId(0);
    //     emit log_named_uint('layerId', layerId);
    //     assertEq(layerId, 1);

    //     distributions = new uint256[](0);

    //     // less than second distribution
    //     distributions.push(0x40); // 0b01000000
    //     distributions.push(0x80); // 0b10000000
    //     uint256 packedDistribution = PackedByteUtility.packArrayOfBytes(
    //         distributions
    //     );
    //     emit log_named_uint('packedDistribution', packedDistribution);
    //     test.setLayerTypeDistribution(
    //         uint8(LayerType.PORTRAIT),
    //         packedDistribution
    //     );
    //     layerId = test.getLayerId(0);
    //     assertEq(layerId, 2);

    //     // greater than second distribution
    //     distributions[1] = 0x60; // 0b01100000
    //     packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
    //     test.setLayerTypeDistribution(
    //         uint8(LayerType.PORTRAIT),
    //         packedDistribution
    //     );
    //     layerId = test.getLayerId(0);
    //     assertEq(layerId, 3);

    //     distributions = new uint256[](0);
    //     for (uint256 i = 1; i <= 32; i++) {
    //         distributions.push(i);
    //     }
    //     packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
    //     test.setLayerTypeDistribution(
    //         uint8(LayerType.PORTRAIT),
    //         packedDistribution
    //     );
    //     layerId = test.getLayerId(0);
    //     assertEq(layerId, 32);

    //     // first byte is 0x18, or 0b00011000
    //     // less than first byte
    //     distributions = new uint256[](0);
    //     distributions.push(0x19);
    //     distributions.push(0x20);
    //     packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
    //     test.setLayerTypeDistribution(
    //         uint8(LayerType.BACKGROUND),
    //         packedDistribution
    //     );
    //     layerId = test.getLayerId(1);
    //     assertEq(layerId, 33);

    //     // greater than first byte
    //     distributions[0] = 0x17;
    //     packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
    //     test.setLayerTypeDistribution(
    //         uint8(LayerType.BACKGROUND),
    //         packedDistribution
    //     );
    //     layerId = test.getLayerId(1);
    //     assertEq(layerId, 34);

    //     // greater than second byte
    //     distributions[0] = 0x16;
    //     distributions[1] = 0x17;
    //     packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
    //     test.setLayerTypeDistribution(
    //         uint8(LayerType.BACKGROUND),
    //         packedDistribution
    //     );
    //     layerId = test.getLayerId(1);
    //     assertEq(layerId, 35);

    //     distributions = new uint256[](0);
    //     distributions.push(0x1);
    //     distributions.push(0x2);
    //     distributions.push(0x3);
    //     distributions.push(0x4);
    // }
}
