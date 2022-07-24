// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {OnChainTraits} from '../traits/OnChainTraits.sol';
import {svg} from '../SVG.sol';
import {json} from '../lib/JSON.sol';
import {Layerable} from './Layerable.sol';
import {IImageLayerable} from './IImageLayerable.sol';
import {InvalidInitialization} from '../interface/Errors.sol';
import {Attribute} from '../interface/Structs.sol';
import {DisplayType} from '../interface/Enums.sol';
import {Base64} from 'solady/utils/Base64.sol';
import {LibString} from 'solady/utils/LibString.sol';

contract ImageLayerable is Layerable, IImageLayerable {
    // TODO: different strings impl?
    using LibString for uint256;

    string defaultURI;
    // todo: use different URIs for solo layers and layered layers?
    string baseLayerURI;

    // TODO: add baseLayerURI
    constructor(string memory _defaultURI, address _owner) Layerable(_owner) {
        _initialize(_defaultURI);
    }

    function initialize(address _owner, string memory _defaultURI)
        public
        virtual
    {
        super._initialize(_owner);
        _initialize(_defaultURI);
    }

    function _initialize(string memory _defaultURI) internal virtual {
        if (address(this).code.length > 0) {
            revert InvalidInitialization();
        }
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
     * @notice get the raw URI of a set of token traits, not encoded as a data uri
     * @param layerId the layerId of the base token
     * @param bindings the bitmap of bound traits
     * @param activeLayers packed array of active layerIds as bytes
     * @param layerSeed the random seed for random generation of traits, used to determine if layers have been revealed
     * @return the complete URI of the token, including image and all attributes
     */
    function _getRawTokenJson(
        uint256 layerId,
        uint256 bindings,
        uint256[] calldata activeLayers,
        bytes32 layerSeed
    ) internal view virtual override returns (string memory) {
        // return default uri
        if (layerSeed == 0) {
            return _constructJson(getDefaultImageURI(layerId), '');
        }
        // if no bindings, format metadata as an individual NFT
        // check if bindings == 0 or 1; bindable layers will be treated differently
        else if (bindings == 0 || bindings == 1) {
            return _getRawLayerJson(layerId);
        } else {
            return
                _constructJson(
                    getLayeredTokenImageURI(activeLayers),
                    getBoundAndActiveLayerTraits(bindings, activeLayers)
                );
        }
    }

    function _getRawLayerJson(uint256 layerId)
        internal
        view
        virtual
        override
        returns (string memory)
    {
        Attribute memory layerTypeAttribute = traitAttributes[layerId];
        layerTypeAttribute.value = layerTypeAttribute.traitType;
        layerTypeAttribute.traitType = 'Layer Type';
        layerTypeAttribute.displayType = DisplayType.String;
        return
            _constructJson(
                getLayerImageURI(layerId),
                json.array(
                    json._commaJoin(
                        _getAttributeJson(layerTypeAttribute),
                        getLayerTraitJson(layerId)
                    )
                )
            );
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
                'data:image/svg+xml;base64,',
                Base64.encode(
                    bytes(
                        string.concat(
                            '<svg xmlns="http://www.w3.org/2000/svg">',
                            layerImages,
                            '</svg>'
                        )
                    )
                )
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
        return string.concat(baseLayerURI, layerId.toString());
    }

    /// @notice get the default URI for a layerId
    function getDefaultImageURI(uint256)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return defaultURI;
    }

    /// @dev helper to wrap imageURI and optional attributes into a JSON object string
    function _constructJson(string memory imageURI, string memory attributes)
        internal
        pure
        returns (string memory)
    {
        if (bytes(attributes).length > 0) {
            string[] memory properties = new string[](2);
            properties[0] = json.property('image', imageURI);
            // attributes should be a JSON array, no need to wrap it in quotes
            properties[1] = json.rawProperty('attributes', attributes);
            return json.objectOf(properties);
        }
        return json.object(json.property('image', imageURI));
    }
}
