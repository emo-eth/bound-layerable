// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {TestToken} from 'bound-layerable/implementations/TestToken.sol';

import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {ERC721Recipient} from './util/ERC721Recipient.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {BitMapUtility} from 'bound-layerable/lib/BitMapUtility.sol';

contract TestTokenTest is Test, ERC721Recipient {
    TestToken test;
    uint256[] distributions;

    function setUp() public virtual {
        test = new TestToken('Test', 'test', '');
        test.setPackedBatchRandomness(bytes32(uint256(1)));
    }

    function testDoTheMost() public {
        // // todo: set rarities

        // 6 backgrounds
        distributions = [
            uint256(42 * 256),
            uint256(84 * 256),
            uint256(126 * 256),
            uint256(168 * 256),
            uint256(210 * 256),
            uint256(252 * 256)
        ];

        uint256[] memory _distributions = distributions;
        uint256[2] memory packedDistributions = PackedByteUtility
            .packArrayOfShorts(_distributions);
        test.setLayerTypeDistribution(
            uint8(LayerType.BACKGROUND),
            packedDistributions
        );

        packedDistributions = [uint256(2**16 - 1) << 240, uint256(0)];

        // 1 portrait
        test.setLayerTypeDistribution(
            uint8(LayerType.PORTRAIT),
            packedDistributions
        );

        // 5 textures
        distributions = [
            uint256(51 * 256),
            uint256(102 * 256),
            uint256(153 * 256),
            uint256(204 * 256),
            uint256(255 * 256)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packArrayOfShorts(
            _distributions
        );

        test.setLayerTypeDistribution(
            uint8(LayerType.TEXTURE),
            packedDistributions
        );

        // 8 objects
        distributions = [
            uint256(31 * 256),
            uint256(62 * 256),
            uint256(93 * 256),
            uint256(124 * 256),
            uint256(155 * 256),
            uint256(186 * 256),
            uint256(217 * 256),
            uint256(248 * 256)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packArrayOfShorts(
            _distributions
        );
        test.setLayerTypeDistribution(
            uint8(LayerType.OBJECT),
            packedDistributions
        );

        // 7 borders
        distributions = [
            uint256(36 * 256),
            uint256(72 * 256),
            uint256(108 * 256),
            uint256(144 * 256),
            uint256(180 * 256),
            uint256(216 * 256),
            uint256(252 * 256)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packArrayOfShorts(
            _distributions
        );
        test.setLayerTypeDistribution(
            uint8(LayerType.BORDER),
            packedDistributions
        );

        // test.setBaseLayerURI(
        //     '/Users/jameswenzel/dev/partner-smart-contracts/Layers/'
        // );

        // // do the thing

        uint256 tokenId = 6;

        test.mintSet();
        uint256 startingTokenId = tokenId * 7;

        // get layerIds from token IDs
        uint256[] memory layers = new uint256[](7);
        for (
            uint256 layerTokenId = startingTokenId;
            layerTokenId < startingTokenId + 7;
            layerTokenId++
        ) {
            uint256 layer = test.getLayerId(layerTokenId);
            emit log_named_uint('layer', layer);
            uint256 lastLayer = 0;
            if (layerTokenId > startingTokenId) {
                lastLayer = layers[(layerTokenId % 7) - 1];
            }
            if (layer == lastLayer) {
                emit log('oops');
                layer += 1;
            }
            layers[layerTokenId % 7] = uint256(layer);
            emit log_named_uint('copied layer', layers[layerTokenId % 7]);
        }

        // create copy as uint256 bc todo: i need to fix
        uint256 packedLayers = PackedByteUtility.packArrayOfBytes(layers);

        emit log_named_uint('packedLayers', packedLayers);

        uint256 binding = BitMapUtility.uintsToBitMap(layers);

        emit log_named_uint('binding', binding);
        test.setBoundLayers(tokenId * 7, binding);

        // swap layer ordering
        uint256 temp = layers[0];
        layers[0] = layers[1];
        layers[1] = temp;
        uint256 newPackedLayers = PackedByteUtility.packArrayOfBytes(layers);
        // set active layers - use portrait id, not b
        test.setActiveLayers(startingTokenId, newPackedLayers);
        uint256[] memory activeLayers = test.getActiveLayers(startingTokenId);
        for (uint256 i; i < activeLayers.length; i++) {
            emit log_named_uint('activeLayer', activeLayers[i]);
        } // emit log(test.metadataContract().getTokenSVG(startingTokenId));
    }
}
