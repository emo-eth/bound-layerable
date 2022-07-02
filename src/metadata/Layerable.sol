// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {OnChainTraits} from '../traits/OnChainTraits.sol';
import {svg, utils} from '../SVG.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {RandomTraits} from '../traits/RandomTraits.sol';
import {json} from '../lib/JSON.sol';
import {BitMapUtility} from '../lib/BitMapUtility.sol';
import {PackedByteUtility} from '../lib/PackedByteUtility.sol';
import {ILayerable} from './ILayerable.sol';

contract Layerable is ILayerable, OnChainTraits {
    // TODO: different strings impl?
    using Strings for uint256;
    using BitMapUtility for uint256;

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

    function getLayerTraits(uint256 bindings)
        public
        view
        returns (string memory)
    {
        return json.arrayOf(_getLayerTraits(bindings));
    }

    function getActiveLayerTraits(uint256[] calldata activeLayers)
        public
        view
        returns (string memory)
    {
        return json.arrayOf(_getActiveLayerTraits(activeLayers));
    }

    function _getLayerTraits(uint256 bindings)
        internal
        view
        returns (string[] memory layerTraits)
    {
        uint256[] memory boundLayers = BitMapUtility.unpackBitMap(bindings);
        layerTraits = new string[](boundLayers.length);
        for (uint256 i; i < boundLayers.length; ++i) {
            layerTraits[i] = getTraitJson(boundLayers[i]);
        }
    }

    // eg 'Background' -> 'Active Background'
    function _getActiveLayerTraits(uint256[] calldata activeLayers)
        internal
        view
        returns (string[] memory activeLayerTraits)
    {
        activeLayerTraits = new string[](activeLayers.length);
        for (uint256 i; i < activeLayers.length; ++i) {
            activeLayerTraits[i] = getTraitJson(activeLayers[i], 'Active');
        }
    }

    function getLayerAndActiveTraits(
        uint256 bindings,
        uint256[] calldata activeLayers
    ) public view returns (string memory) {
        string[] memory layerTraits = _getLayerTraits(bindings);
        string[] memory activeLayerTraits = _getActiveLayerTraits(activeLayers);
        return json.arrayOf(layerTraits, activeLayerTraits);
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
        // check if bindings == 0 or 1; bindable traits will be treated differently
        if (bindings == 0 || bindings == 0) {
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
                getLayerTraits(bindings)
            );
        }
        return json.objectOf(properties);
    }
}
