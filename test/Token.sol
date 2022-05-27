// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";

import {PackedByteUtility} from "../src/utils/PackedByteUtility.sol";
import {RandomTraits} from "../src/utils/RandomTraits.sol";
import {ERC721Recipient} from "./utils/ERC721Recipient.sol";

contract TokenTest is Test, ERC721Recipient {
    Token test;
    uint8[] distributions;

    function setUp() public virtual override {
        super.setUp();
        test = new Token("Test", "test");
    }

    function testSetDisableTrading() public {
        vm.prank(alice);
        // test.mintSet{value: .1 ether}();
        // test.setInactive();
    }

    function testDoTheMost() public {
        // // todo: set rarities

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
            RandomTraits.LayerType.BACKGROUND,
            packedDistributions[0]
        );

        // 1 portrait
        test.setLayerTypeDistribution(
            RandomTraits.LayerType.PORTRAIT,
            255 << 248
        );

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
            RandomTraits.LayerType.TEXTURE,
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
        test.setLayerTypeDistribution(
            RandomTraits.LayerType.OBJECT,
            packedDistributions[0]
        );

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
        test.setLayerTypeDistribution(
            RandomTraits.LayerType.BORDER,
            packedDistributions[0]
        );

        test.setBaseLayerURI(
            "/Users/jameswenzel/dev/partner-smart-contracts/Layers/"
        );

        // // do the thing

        uint256 _tokenId = 6;

        test.mintSet();
        uint256 startingTokenId = _tokenId * 7;

        // get layerIds from token IDs
        uint8[] memory layers = new uint8[](7);
        for (
            uint256 layerTokenId = startingTokenId;
            layerTokenId < startingTokenId + 7;
            layerTokenId++
        ) {
            uint256 layer = test.getLayerId(layerTokenId);
            emit log_named_uint("layer", layer);
            uint256 lastLayer = 0;
            if (layerTokenId > startingTokenId) {
                lastLayer = layers[(layerTokenId % 7) - 1];
            }
            if (layer == lastLayer) {
                emit log("oops");
                layer += 1;
            }
            layers[layerTokenId % 7] = uint8(layer);
            emit log_named_uint("copied layer", layers[layerTokenId % 7]);
        }

        // create copy as uint256 bc todo: i need to fix
        uint256[] memory packedLayers = PackedByteUtility.packBytearray(layers);

        emit log_named_uint("packedLayers", packedLayers[0]);

        // unpack layerIDs into a binding - todo: make this a public function idk
        uint256 binding = test.packedLayersToBitField(packedLayers);
        emit log_named_uint("binding", binding);
        test.bindLayers(_tokenId * 7, binding);

        // swap layer ordering
        uint8 temp = layers[0];
        layers[0] = layers[1];
        layers[1] = temp;
        uint256[] memory newPackedLayers = PackedByteUtility.packBytearray(
            layers
        );
        // set active layers - use portrait id, not b
        test.setActiveLayers(startingTokenId, newPackedLayers);
        uint256[] memory activeLayers = test.getActiveLayers(startingTokenId);
        for (uint256 i; i < activeLayers.length; i++) {
            emit log_named_uint("activeLayer", activeLayers[i]);
        }
        emit log(test.getTokenSVG(startingTokenId));
    }
}
