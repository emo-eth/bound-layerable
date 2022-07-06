// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraitsImpl as RandomTraitsImplLayer} from 'bound-layerable/traits/RandomTraitsImpl.sol';

contract RandomTraitsImpl is RandomTraitsImplLayer {
    constructor() RandomTraits('', '', address(1234), 5555, 7, 1) {}

    function setTraitGenerationSeed(bytes32 _seed) public {
        traitGenerationSeed = _seed;
    }
}

contract RandomTraitsTest is Test {
    RandomTraitsImpl test;

    function setUp() public {
        test = new RandomTraitsImpl();
    }

    uint256[] distributions;

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

        // % 7 == 4 should be border
        assertEq(uint256(test.getLayerType(4)), 4);
        assertEq(uint256(test.getLayerType(11)), 4);

        // % 7 == 5 should be object
        assertEq(uint256(test.getLayerType(5)), 3);
        assertEq(uint256(test.getLayerType(12)), 3);

        // % 7 == 6 should be border
        assertEq(uint256(test.getLayerType(6)), 4);
        assertEq(uint256(test.getLayerType(13)), 4);
    }

    function testGetLayerId() public {
        test.setTraitGenerationSeed(bytes32(uint256(42)));
        emit log_named_bytes32('seed', test.traitGenerationSeed());
        // first byte is 0x64, or 0b01100100
        emit log_named_bytes32(
            'hash 1',
            keccak256(
                abi.encode(
                    test.traitGenerationSeed(),
                    uint256(1),
                    uint8(LayerType.BACKGROUND)
                )
            )
        );
        // less than first distribution
        distributions = new uint256[](0);
        distributions.push(0x80);
        distributions.push(0xc0);
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            PackedByteUtility.packArrayOfBytes(distributions)
        );
        uint256 layerId = test.getLayerId(0);
        emit log_named_uint('layerId', layerId);
        assertEq(layerId, 1);

        distributions = new uint256[](0);

        // less than second distribution
        distributions.push(0x40); // 0b01000000
        distributions.push(0x80); // 0b10000000
        uint256 packedDistribution = PackedByteUtility.packArrayOfBytes(
            distributions
        );
        emit log_named_uint('packedDistribution', packedDistribution);
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            packedDistribution
        );
        layerId = test.getLayerId(0);
        assertEq(layerId, 2);

        // greater than second distribution
        distributions[1] = 0x60; // 0b01100000
        packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            packedDistribution
        );
        layerId = test.getLayerId(0);
        assertEq(layerId, 3);

        distributions = new uint256[](0);
        for (uint256 i = 1; i <= 32; i++) {
            distributions.push(i);
        }
        packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            packedDistribution
        );
        layerId = test.getLayerId(0);
        assertEq(layerId, 32);

        // first byte is 0x18, or 0b00011000
        // less than first byte
        distributions = new uint256[](0);
        distributions.push(0x19);
        distributions.push(0x20);
        packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
        test.setLayerTypeDistribution(
            uint8(LayerType.BACKGROUND),
            packedDistribution
        );
        layerId = test.getLayerId(1);
        assertEq(layerId, 33);

        // greater than first byte
        distributions[0] = 0x17;
        packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
        test.setLayerTypeDistribution(
            uint8(LayerType.BACKGROUND),
            packedDistribution
        );
        layerId = test.getLayerId(1);
        assertEq(layerId, 34);

        // greater than second byte
        distributions[0] = 0x16;
        distributions[1] = 0x17;
        packedDistribution = PackedByteUtility.packArrayOfBytes(distributions);
        test.setLayerTypeDistribution(
            uint8(LayerType.BACKGROUND),
            packedDistribution
        );
        layerId = test.getLayerId(1);
        assertEq(layerId, 35);

        distributions = new uint256[](0);
        distributions.push(0x1);
        distributions.push(0x2);
        distributions.push(0x3);
        distributions.push(0x4);
    }
}
