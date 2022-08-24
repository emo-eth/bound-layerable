// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {svg} from 'hot-chain-svg/SVG.sol';
import {utils} from 'hot-chain-svg/Utils.sol';
import {TestToken} from './implementations/TestToken.sol';
import {PackedByteUtility} from './lib/PackedByteUtility.sol';
import {RandomTraits} from './traits/RandomTraits.sol';
import {ERC721Recipient} from '../test/util/ERC721Recipient.sol';
import {LayerType} from './interface/Enums.sol';
import {ImageLayerable} from './metadata/ImageLayerable.sol';

contract Renderer is ERC721Recipient {
    TestToken test;
    uint256[] distributions;

    constructor() {
        test = new TestToken('Token', 'test', '');
        // todo: set rarities
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
        packedDistributions = [uint256(2**16) << 240, uint256(0)];

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
            uint256(36),
            uint256(72),
            uint256(108),
            uint256(144),
            uint256(180),
            uint256(216),
            uint256(252)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packArrayOfShorts(
            _distributions
        );
        test.setLayerTypeDistribution(
            uint8(LayerType.BORDER),
            packedDistributions
        );
        ImageLayerable(address(test.metadataContract())).setBaseLayerURI(
            '/Users/jameswenzel/dev/partner-smart-contracts/Layers/'
        );
    }

    function render(uint256 tokenId) public returns (string memory) {
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
            uint256 lastLayer = 0;
            if (layerTokenId > startingTokenId) {
                lastLayer = layers[(layerTokenId % 7) - 1];
            }
            if (layer == lastLayer) {
                layer += 1;
            }
            if (layer == 2) {
                layer = 1;
            }
            layers[layerTokenId % 7] = uint256(layer);
        }
        // create copy as uint256 bc todo: i need to fix
        // uint256[] memory packedLayers = PackedByteUtility.packArrayOfShorts(layers);
        // unpack layerIDs into a binding - todo: make this a public function idk
        // uint256 binding = test.packedLayersToBitMap(packedLayers);
        // test.bindLayers(startingTokenId, binding);
        // swap layer ordering
        uint256 temp = layers[0];
        layers[0] = layers[1];
        layers[1] = temp;
        // uint256[] memory newPackedLayers = PackedByteUtility.packArrayOfShorts(
        //     layers
        // );
        // set active layers - use portrait id, not b
        // test.setActiveLayers(startingTokenId, newPackedLayers);
        return test.metadataContract().getLayeredTokenImageURI(layers);
    }

    function example() external returns (string memory) {
        return render(0);
    }
}
