//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {svg} from './SVG.sol';
import {utils} from './Utils.sol';
import {Token} from './Token.sol';
import {PackedByteUtility} from './lib/PackedByteUtility.sol';
import {RandomTraits} from './traits/RandomTraits.sol';
import {ERC721Recipient} from './utils/ERC721Recipient.sol';
import {LayerType} from './interface/Enums.sol';

contract Renderer is ERC721Recipient {
    Token test;
    uint8[] distributions;

    constructor() {
        test = new Token('Token', 'test', '');
        // todo: set rarities
        // 6 backgrounds
        distributions = [
            uint8(42),
            uint8(84),
            uint8(126),
            uint8(168),
            uint8(210),
            uint8(252)
        ];
        uint8[] memory _distributions = distributions;
        uint256[] memory packedDistributions = PackedByteUtility.packBytearray(
            _distributions
        );
        test.setLayerTypeDistribution(
            LayerType.BACKGROUND,
            packedDistributions[0]
        );
        // 1 portrait
        test.setLayerTypeDistribution(LayerType.PORTRAIT, 255 << 248);
        // 5 textures
        distributions = [
            uint8(51),
            uint8(102),
            uint8(153),
            uint8(204),
            uint8(255)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packBytearray(_distributions);
        test.setLayerTypeDistribution(
            LayerType.TEXTURE,
            packedDistributions[0]
        );
        // 8 objects
        distributions = [
            uint8(31),
            uint8(62),
            uint8(93),
            uint8(124),
            uint8(155),
            uint8(186),
            uint8(217),
            uint8(248)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packBytearray(_distributions);
        test.setLayerTypeDistribution(LayerType.OBJECT, packedDistributions[0]);
        // 7 borders
        distributions = [
            uint8(36),
            uint8(72),
            uint8(108),
            uint8(144),
            uint8(180),
            uint8(216),
            uint8(252)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packBytearray(_distributions);
        test.setLayerTypeDistribution(LayerType.BORDER, packedDistributions[0]);
        test.metadataContract().setBaseLayerURI(
            '/Users/jameswenzel/dev/partner-smart-contracts/Layers/'
        );
    }

    function render(uint256 _tokenId) public returns (string memory) {
        test.mintSet();
        uint256 startingTokenId = _tokenId * 7;
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
            layers[layerTokenId % 7] = uint8(layer);
        }
        // create copy as uint256 bc todo: i need to fix
        // uint256[] memory packedLayers = PackedByteUtility.packBytearray(layers);
        // unpack layerIDs into a binding - todo: make this a public function idk
        // uint256 binding = test.packedLayersToBitField(packedLayers);
        // test.bindLayers(startingTokenId, binding);
        // swap layer ordering
        uint256 temp = layers[0];
        layers[0] = layers[1];
        layers[1] = temp;
        // uint256[] memory newPackedLayers = PackedByteUtility.packBytearray(
        //     layers
        // );
        // set active layers - use portrait id, not b
        // test.setActiveLayers(startingTokenId, newPackedLayers);
        return test.metadataContract().getTokenSVG(layers);
    }

    function example() external returns (string memory) {
        return render(0);
    }
}
