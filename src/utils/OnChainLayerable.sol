// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerable} from './BoundLayerable.sol';
import {OnChainTraits} from './OnChainTraits.sol';
import {svg, utils} from '../SVG.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {RandomTraits} from './RandomTraits.sol';
import {json} from './JSON.sol';
import {BitMapUtility} from './BitMapUtility.sol';

contract OnChainLayerable is OnChainTraits {
    // TODO: different strings impl?
    using Strings for uint256;

    string defaultURI;
    string baseLayerURI;

    constructor(string memory _defaultURI, address _owner) {
        defaultURI = _defaultURI;
        transferOwnership(_owner);
    }

    function setDefaultURI(string calldata _defaultURI) public onlyOwner {
        defaultURI = _defaultURI;
    }

    function setBaseLayerURI(string calldata _baseLayerURI) external onlyOwner {
        baseLayerURI = _baseLayerURI;
    }

    function getLayerURI(uint256 _layerId) public view returns (string memory) {
        return string.concat(baseLayerURI, _layerId.toString(), '.png');
    }

    function getTokenSVG(uint256[] calldata activeLayers)
        public
        view
        returns (string memory)
    {
        string memory layerImages = '';
        for (uint256 i; i < activeLayers.length; ++i) {
            string memory layerUri = getLayerURI(activeLayers[i]);
            layerImages = string.concat(
                layerImages,
                svg.image(layerUri, svg.prop('height', '100%'))
            );
        }

        return
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg">',
                layerImages,
                '</svg>'
            );
    }

    function getTokenTraits(uint256 bindings)
        public
        view
        returns (string memory)
    {
        uint256[] memory boundLayers = BitMapUtility.unpackBitMap(bindings);
        string[] memory layerTraits = new string[](boundLayers.length);
        for (uint256 i; i < boundLayers.length; ++i) {
            layerTraits[i] = getTraitJson(boundLayers[i]);
        }
        return json.arrayOf(layerTraits);
    }

    // TODO: restrict so other contracts cannot call?
    function getTokenURI(
        uint256 layerId,
        uint256 bindings,
        bytes32 traitGenerationSeed,
        uint256[] calldata activeLayers
    ) public view virtual returns (string memory) {
        string[] memory properties = new string[](2);

        // return default uri
        if (traitGenerationSeed == 0) {
            return defaultURI;
        }
        // uint256 bindings = _tokenIdToBoundLayers[_tokenId];

        // if no bindings, format metadata as an individual NFT
        // TODO explore setting bindings to 1
        if (bindings == 0) {
            // uint256 layerId = getLayerId(_tokenId);
            properties[0] = json.property('image', getLayerURI(layerId));
            properties[1] = json.property(
                'attributes',
                json.array(getTraitJson(layerId))
            );
        } else {
            properties[0] = json.property('image', getTokenSVG(activeLayers));
            properties[1] = json.property(
                'attributes',
                getTokenTraits(bindings)
            );
        }
        return json.objectOf(properties);
    }
}
