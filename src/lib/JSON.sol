// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Strings} from 'openzeppelin-contracts/utils/Strings.sol';

library json {
    using Strings for uint256;

    function object(string memory value) internal pure returns (string memory) {
        return string.concat('{', value, '}');
    }

    function array(string memory value) internal pure returns (string memory) {
        return string.concat('[', value, ']');
    }

    function property(string memory name, string memory value)
        internal
        pure
        returns (string memory)
    {
        return string.concat('"', name, '":"', value, '"');
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

    function arrayOf(string[] memory values)
        internal
        pure
        returns (string memory)
    {
        return array(_commaJoin(values));
    }

    function arrayOf(string[] memory values1, string[] memory values2)
        internal
        pure
        returns (string memory)
    {
        if (values1.length == 0) {
            return arrayOf(values2);
        } else if (values2.length == 0) {
            return arrayOf(values1);
        }
        return
            array(string.concat(_commaJoin(values1), ',', _commaJoin(values2)));
    }

    function quote(string memory str) internal pure returns (string memory) {
        return string.concat('"', str, '"');
    }

    function _commaJoin(string[] memory values)
        internal
        pure
        returns (string memory result)
    {
        return _join(values, ',');
    }

    function _join(string[] memory values, string memory separator)
        internal
        pure
        returns (string memory result)
    {
        if (values.length == 0) {
            return '';
        }
        result = values[0];
        for (uint256 i = 1; i < values.length; ++i) {
            result = string.concat(result, separator, values[i]);
        }
    }
}
