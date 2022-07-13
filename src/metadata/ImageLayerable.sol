// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {OnChainTraits} from '../traits/OnChainTraits.sol';
import {svg, utils} from '../SVG.sol';
import {Strings} from 'openzeppelin-contracts//utils/Strings.sol';
import {RandomTraits} from '../traits/RandomTraits.sol';
import {json} from '../lib/JSON.sol';
import {BitMapUtility} from '../lib/BitMapUtility.sol';
import {PackedByteUtility} from '../lib/PackedByteUtility.sol';
import {Layerable} from './Layerable.sol';
import {IImageLayerable} from './IImageLayerable.sol';
import {Strings} from 'openzeppelin-contracts//utils/Strings.sol';

contract ImageLayerable is Layerable, IImageLayerable {
    // TODO: different strings impl?
    using Strings for uint256;

    string defaultURI;
    // todo: use different URIs for solo layers and layered layers?
    string baseLayerURI;

    constructor(string memory _defaultURI, address _owner) Layerable(_owner) {
        defaultURI = _defaultURI;
    }

    /// @notice set the default URI for unrevealed tokens
    function setDefaultURI(string memory _defaultURI) public onlyOwner {
        defaultURI = _defaultURI;
    }

    /// @notice set the base URI for layers
    function setBaseLayerURI(string memory _baseLayerURI) public onlyOwner {
        baseLayerURI = _baseLayerURI;
    }

    /**
     * @notice get the complete URI of a set of token traits
     * @param layerId the layerId of the base token
     * @param bindings the bitmap of bound traits
     * @param activeLayers packed array of active layerIds as bytes
     * @param layerSeed the random seed for random generation of traits, used to determine if layers have been revealed
     * @return the complete URI of the token, including image and all attributes
     */
    function getTokenURI(
        uint256 layerId,
        uint256 bindings,
        uint256[] calldata activeLayers,
        bytes32 layerSeed
    ) public view virtual override returns (string memory) {
        string[] memory properties = new string[](2);

        // return default uri
        if (layerSeed == 0) {
            return defaultURI;
        }

        // if no bindings, format metadata as an individual NFT
        // check if bindings == 0 or 1; bindable traits will be treated differently
        // TODO: test this if/else
        if (bindings == 0 || bindings == 1) {
            properties[0] = json.property('image', getLayerImageURI(layerId));
            properties[1] = json.property(
                'attributes',
                json.array(getTraitJson(layerId))
            );
        } else {
            properties[0] = json.property(
                'image',
                getLayeredTokenImageURI(activeLayers)
            );
            properties[1] = json.property(
                'attributes',
                getBoundLayerTraits(bindings)
            );
        }
        return json.objectOf(properties);
    }

    /// @notice get the complete SVG for a set of activeLayers
    function getLayeredTokenImageURI(uint256[] calldata activeLayers)
        public
        view
        virtual
        override
        returns (string memory)
    {
        string memory layerImages = '';
        for (uint256 i; i < activeLayers.length; ++i) {
            string memory layerUri = getLayerImageURI(activeLayers[i]);
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

    /// @notice get the image URI for a layerId
    function getLayerImageURI(uint256 layerId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        // TODO: remove png?
        return string.concat(baseLayerURI, layerId.toString(), '.png');
    }
}
