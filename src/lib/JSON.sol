// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Strings} from '@openzeppelin/contracts/utils/Strings.sol';

library json {
    using Strings for uint256;

    function object(string memory _value)
        internal
        pure
        returns (string memory)
    {
        return string.concat('{', _value, '}');
    }

    function objectOf(string[] memory properties)
        internal
        pure
        returns (string memory)
    {
        if (properties.length == 0) {
            return object('');
        }
        string memory result = properties[0];
        for (uint256 i = 1; i < properties.length; ++i) {
            result = string.concat(result, ',', properties[i]);
        }
        return object(result);
    }

    function array(string memory _value) internal pure returns (string memory) {
        return string.concat('[', _value, ']');
    }

    function arrayOf(string[] memory _values)
        internal
        pure
        returns (string memory)
    {
        if (_values.length == 0) {
            return array('');
        }
        string memory _result = _values[0];
        for (uint256 i = 1; i < _values.length; ++i) {
            _result = string.concat(_result, ',', _values[i]);
        }
        return array(_result);
    }

    function property(string memory _name, string memory _value)
        internal
        pure
        returns (string memory)
    {
        return string.concat('"', _name, '":"', _value, '"');
    }
}
