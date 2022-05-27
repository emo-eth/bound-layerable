// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {BoundLayerable} from "./BoundLayerable.sol";
import {OnChainTraits} from "./OnChainTraits.sol";
import {svg, utils} from "../SVG.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {RandomTraits} from "./RandomTraits.sol";
import {json} from "./JSON.sol";

// import {DSTestPlusPlus} from 'src/test/utils/DSTestPlusPlus.sol';

contract OnChainLayerable is OnChainTraits, RandomTraits, BoundLayerable {
    using Strings for uint256;

    string defaultURI;

    constructor(string memory _defaultURI) RandomTraits(7) {
        defaultURI = _defaultURI;
    }

    function setDefaultURI(string calldata _defaultURI) public onlyOwner {
        defaultURI = _defaultURI;
    }

    function getLayerURI(uint256 _layerId) public view returns (string memory) {
        return string.concat(baseLayerURI, _layerId.toString(), ".png");
    }

    function getTokenSVG(uint256 _tokenId) public view returns (string memory) {
        uint256[] memory activeLayers = getActiveLayers(_tokenId);
        string memory layerImages = "";
        for (uint256 i; i < activeLayers.length; ++i) {
            string memory layerUri = getLayerURI(activeLayers[i]);
            // emit log(layerUri);
            layerImages = string.concat(
                layerImages,
                svg.image(layerUri, svg.prop("height", "100%"))
            );
        }

        return
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg">',
                layerImages,
                "</svg>"
            );
    }

    function getTokenTraits(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        uint256[] memory boundLayers = getBoundLayers(_tokenId);
        string[] memory layerTraits = new string[](boundLayers.length);
        for (uint256 i; i < boundLayers.length; ++i) {
            layerTraits[i] = getTraitJson(boundLayers[i]);
        }
        return json.arrayOf(layerTraits);
    }

    function getTokenURI(uint256 _tokenId)
        internal
        view
        virtual
        returns (string memory)
    {
        string[] memory properties = new string[](2);

        // return default uri
        if (traitGenerationSeed == 0) {
            return defaultURI;
        }
        uint256 bindings = _tokenIdToBoundLayers[_tokenId];

        // if no bindings, format metadata as an individual NFT
        if (bindings == 0) {
            uint256 layerId = getLayerId(_tokenId);
            properties[0] = json.property("image", getLayerURI(layerId));
            properties[1] = json.property(
                "attributes",
                json.array(getTraitJson(layerId))
            );
        } else {
            properties[0] = json.property("image", getTokenSVG(_tokenId));
            properties[1] = json.property(
                "attributes",
                getTokenTraits(_tokenId)
            );
        }
        return json.objectOf(properties);
    }
}
