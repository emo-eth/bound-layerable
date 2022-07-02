// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {OnChainTraits} from '../traits/OnChainTraits.sol';
import {svg, utils} from '../SVG.sol';
import {RandomTraits} from '../traits/RandomTraits.sol';
import {json} from '../lib/JSON.sol';
import {BitMapUtility} from '../lib/BitMapUtility.sol';
import {PackedByteUtility} from '../lib/PackedByteUtility.sol';
import {ILayerable} from './ILayerable.sol';

abstract contract Layerable is ILayerable, OnChainTraits {
    using BitMapUtility for uint256;

    // TODO: make these optional; remove from interface
    string defaultURI;
    // todo: use different URIs for solo layers and layered layers?
    string baseLayerURI;

    constructor(string memory _defaultURI, address _owner) {
        defaultURI = _defaultURI;
        transferOwnership(_owner);
    }

    // TODO: restrict so other contracts cannot call?
    /**
     * @notice get the complete URI of a set of token traits
     * @param layerId the layerId of the base token
     * @param bindings the bitmap of bound traits
     * @param activeLayers packed array of active layerIds as bytes
     * @param traitGenerationSeed the random seed for random generation of traits, used to determine if layers have been revealed
     * @return the complete URI of the token, including image and all attributes
     */
    function getTokenURI(
        uint256 layerId,
        uint256 bindings,
        uint256[] calldata activeLayers,
        bytes32 traitGenerationSeed
    ) public view virtual returns (string memory);

    /// @notice get the complete SVG for a set of activeLayers
    function getLayeredTokenImageURI(uint256[] calldata activeLayers)
        public
        view
        virtual
        returns (string memory);

    /// @notice get the image URI for a layerId
    function getLayerImageURI(uint256 layerId)
        public
        view
        virtual
        returns (string memory);

    /// @notice get stringified JSON array of bound layer traits
    function getLayerTraits(uint256 bindings)
        public
        view
        returns (string memory)
    {
        return json.arrayOf(_getLayerTraits(bindings));
    }

    /// @notice get stringified JSON array of active layer traits
    function getActiveLayerTraits(uint256[] calldata activeLayers)
        public
        view
        returns (string memory)
    {
        return json.arrayOf(_getActiveLayerTraits(activeLayers));
    }

    /// @notice get stringified JSON array of combined bound and active layer traits
    function getLayerAndActiveTraits(
        uint256 bindings,
        uint256[] calldata activeLayers
    ) public view returns (string memory) {
        string[] memory layerTraits = _getLayerTraits(bindings);
        string[] memory activeLayerTraits = _getActiveLayerTraits(activeLayers);
        return json.arrayOf(layerTraits, activeLayerTraits);
    }

    /// @notice set the default URI for tokens when they are not revealed. OnlyOwner
    function setDefaultURI(string calldata _defaultURI) public onlyOwner {
        defaultURI = _defaultURI;
    }

    /// @notice set the base URI for layers. OnlyOwner
    function setBaseLayerURI(string calldata _baseLayerURI) external onlyOwner {
        baseLayerURI = _baseLayerURI;
    }

    /// @dev get array of stringified trait json for bindings
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

    /// @dev get array of stringified trait json for active layers. Prepends "Active" to trait title.
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
}
