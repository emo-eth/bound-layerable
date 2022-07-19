// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';
import {PackedByteUtility} from '../lib/PackedByteUtility.sol';
import {Strings} from 'openzeppelin-contracts/utils/Strings.sol';
import {json} from '../lib/JSON.sol';
import {ArrayLengthMismatch} from '../interface/Errors.sol';
import {DisplayType} from '../interface/Enums.sol';
import {Attribute} from '../interface/Structs.sol';

contract OnChainTraits is Ownable {
    using Strings for uint256;

    mapping(uint256 => Attribute) public traitAttributes;

    function setAttribute(uint256 traitId, Attribute calldata attribute)
        public
        onlyOwner
    {
        traitAttributes[traitId] = attribute;
    }

    function setAttributes(
        uint256[] calldata traitIds,
        Attribute[] calldata attributes
    ) public onlyOwner {
        if (traitIds.length != attributes.length) {
            revert ArrayLengthMismatch(traitIds.length, attributes.length);
        }
        for (uint256 i; i < traitIds.length; ++i) {
            traitAttributes[traitIds[i]] = attributes[i];
        }
    }

    function getTraitJson(uint256 traitId) public view returns (string memory) {
        Attribute memory attribute = traitAttributes[traitId];

        string memory properties = string.concat(
            json.property('trait_type', attribute.traitType),
            ','
        );
        return _getTraitJson(properties, attribute);
    }

    function getTraitJson(uint256 traitId, string memory qualifier)
        public
        view
        returns (string memory)
    {
        Attribute memory attribute = traitAttributes[traitId];

        string memory properties = string.concat(
            json.property(
                'trait_type',
                string.concat(qualifier, ' ', attribute.traitType)
            ),
            ','
        );
        return _getTraitJson(properties, attribute);
    }

    function displayTypeJson(string memory displayTypeString)
        internal
        pure
        returns (string memory)
    {
        return json.property('display_type', displayTypeString);
    }

    function _getTraitJson(string memory properties, Attribute memory attribute)
        internal
        pure
        returns (string memory)
    {
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
