// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {TwoStepOwnable} from 'utility-contracts/TwoStepOwnable.sol';
import {PackedByteUtility} from '../lib/PackedByteUtility.sol';
import {LibString} from 'solady/utils/LibString.sol';
import {json} from '../lib/JSON.sol';
import {ArrayLengthMismatch} from '../interface/Errors.sol';
import {DisplayType} from '../interface/Enums.sol';
import {Attribute} from '../interface/Structs.sol';

abstract contract OnChainMultiTraits is TwoStepOwnable {
    using LibString for uint256;

    mapping(uint256 => Attribute[]) public traitAttributes;

    function setAttribute(uint256 layerId, Attribute[] calldata attribute)
        public
        onlyOwner
    {
        _setAttribute(layerId, attribute);
    }

    function setAttributes(
        uint256[] calldata layerIds,
        Attribute[][] calldata attributes
    ) public onlyOwner {
        if (layerIds.length != attributes.length) {
            revert ArrayLengthMismatch(layerIds.length, attributes.length);
        }
        for (uint256 i; i < layerIds.length; ++i) {
            _setAttribute(layerIds[i], attributes[i]);
        }
    }

    function _setAttribute(uint256 layerId, Attribute[] calldata attribute)
        internal
    {
        delete traitAttributes[layerId];
        Attribute[] storage storedAttributes = traitAttributes[layerId];
        uint256 attributesLength = attribute.length;
        for (uint256 i = 0; i < attributesLength; ++i) {
            storedAttributes.push(attribute[i]);
        }
    }

    function getLayerTraitJson(uint256 layerId)
        public
        view
        returns (string memory)
    {
        Attribute[] memory attributes = traitAttributes[layerId];
        uint256 attributesLength = attributes.length;
        string[] memory attributeJsons = new string[](attributesLength);
        for (uint256 i; i < attributesLength; ++i) {
            attributeJsons[i] = getAttributeJson(attributes[i]);
        }
        if (attributesLength == 1) {
            return attributeJsons[0];
        }
        return json._commaJoin(attributeJsons);
    }

    function getLayerTraitJson(uint256 layerId, string memory qualifier)
        public
        view
        returns (string memory)
    {
        Attribute[] memory attributes = traitAttributes[layerId];
        uint256 attributesLength = attributes.length;
        string[] memory attributeJsons = new string[](attributesLength);
        for (uint256 i; i < attributesLength; ++i) {
            attributeJsons[i] = getAttributeJson(attributes[i], qualifier);
        }
        return json._commaJoin(attributeJsons);
    }

    function getAttributeJson(Attribute memory attribute)
        public
        pure
        returns (string memory)
    {
        string memory properties = string.concat(
            json.property('trait_type', attribute.traitType),
            ','
        );
        return _getAttributeJson(properties, attribute);
    }

    function getAttributeJson(
        Attribute memory attribute,
        string memory qualifier
    ) public pure returns (string memory) {
        string memory properties = string.concat(
            json.property(
                'trait_type',
                string.concat(qualifier, ' ', attribute.traitType)
            ),
            ','
        );
        return _getAttributeJson(properties, attribute);
    }

    function displayTypeJson(string memory displayTypeString)
        internal
        pure
        returns (string memory)
    {
        return json.property('display_type', displayTypeString);
    }

    function _getAttributeJson(
        string memory properties,
        Attribute memory attribute
    ) internal pure returns (string memory) {
        // todo: probably don't need this for layers, but good for generic
        DisplayType displayType = attribute.displayType;
        if (displayType != DisplayType.String) {
            string memory displayTypeString;
            if (displayType == DisplayType.Number) {
                displayTypeString = displayTypeJson('number');
            } else if (attribute.displayType == DisplayType.Date) {
                displayTypeString = displayTypeJson('date');
            } else if (attribute.displayType == DisplayType.BoostPercent) {
                displayTypeString = displayTypeJson('boost_percent');
            } else if (attribute.displayType == DisplayType.BoostNumber) {
                displayTypeString = displayTypeJson('boost_number');
            }
            properties = string.concat(properties, displayTypeString, ',');
        }
        properties = string.concat(
            properties,
            json.property('value', attribute.value)
        );
        return json.object(properties);
    }
}
