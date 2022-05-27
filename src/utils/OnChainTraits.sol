// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {PackedByteUtility} from './PackedByteUtility.sol';
import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';
import {json} from './JSON.sol';

contract OnChainTraits is Ownable {
    using Strings for uint256;

    struct Attribute {
        string traitType;
        string value;
        DisplayType displayType;
    }

    enum DisplayType {
        String,
        Number,
        Date,
        BoostPercent,
        BoostNumber
    }

    mapping(uint256 => Attribute) public traitAttributes;

    function setAttribute(uint256 traitId, Attribute memory attribute)
        public
        onlyOwner
    {
        traitAttributes[traitId] = attribute;
    }

    function getTraitJson(uint256 _traitId)
        public
        view
        returns (string memory)
    {
        Attribute memory attribute = traitAttributes[_traitId];
        string memory properties = string.concat(
            json.property('trait_type', attribute.traitType),
            ','
        );
        // todo: probably don't need this for layers, but good for generic
        DisplayType displayType = attribute.displayType;
        if (displayType != DisplayType.String) {
            string memory displayTypeString;
            if (displayType == DisplayType.Number) {
                displayTypeString = json.property('display_type', 'number');
            } else if (attribute.displayType == DisplayType.Date) {
                displayTypeString = json.property('display_type', 'date');
            } else if (attribute.displayType == DisplayType.BoostPercent) {
                displayTypeString = json.property(
                    'display_type',
                    'boost_percent'
                );
            } else if (attribute.displayType == DisplayType.BoostNumber) {
                displayTypeString = json.property(
                    'display_type',
                    'boost_number'
                );
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
