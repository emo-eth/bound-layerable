//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {svg} from './SVG.sol';
import {utils} from './Utils.sol';
import {TestToken} from './test/TestToken.sol';
import {PackedByteUtility} from './lib/PackedByteUtility.sol';
import {RandomTraits} from './traits/RandomTraits.sol';
import {ERC721Recipient} from 'bound-layerable-test/util/ERC721Recipient.sol';
import {LayerType} from './interface/Enums.sol';

contract Renderer is ERC721Recipient {
    TestToken test;
    uint256[] distributions;

    constructor() {
        test = new TestToken('Token', 'test', '');
        // todo: set rarities
        // 6 backgrounds
        distributions = [
            uint256(42),
            uint256(84),
            uint256(126),
            uint256(168),
            uint256(210),
            uint256(252)
        ];
        uint256[] memory _distributions = distributions;
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
            uint256(51),
            uint256(102),
            uint256(153),
            uint256(204),
            uint256(255)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packBytearray(_distributions);
        test.setLayerTypeDistribution(
            LayerType.TEXTURE,
            packedDistributions[0]
        );
        // 8 objects
        distributions = [
            uint256(31),
            uint256(62),
            uint256(93),
            uint256(124),
            uint256(155),
            uint256(186),
            uint256(217),
            uint256(248)
        ];
        _distributions = distributions;
        packedDistributions = PackedByteUtility.packBytearray(_distributions);
        test.setLayerTypeDistribution(LayerType.OBJECT, packedDistributions[0]);
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
            layers[layerTokenId % 7] = uint256(layer);
        }
        // create copy as uint256 bc todo: i need to fix
        // uint256[] memory packedLayers = PackedByteUtility.packBytearray(layers);
        // unpack layerIDs into a binding - todo: make this a public function idk
        // uint256 binding = test.packedLayersToBitMap(packedLayers);
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
        return test.metadataContract().getLayeredTokenImageURI(layers);
    }

    function example() external returns (string memory) {
        return render(0);
    }
}
