// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Strings} from 'openzeppelin-contracts/utils/Strings.sol';

library json {
    using Strings for uint256;

    function object(string memory value) internal pure returns (string memory) {
        return string.concat('{', value, '}');
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

    function array(string memory value) internal pure returns (string memory) {
        return string.concat('[', value, ']');
    }

    function arrayOf(string[] memory values)
        internal
        pure
        returns (string memory)
    {
        return array(_join(values));
    }

    function arrayOf(string[] memory values1, string[] memory values2)
        internal
        pure
        returns (string memory)
    {
        return array(string.concat(_join(values1), _join(values2)));
    }

    function _join(string[] memory values)
        internal
        pure
        returns (string memory result)
    {
        if (values.length == 0) {
            return '';
        }
        result = values[0];
        for (uint256 i = 1; i < values.length; ++i) {
            result = string.concat(result, ',', values[i]);
        }
    }

    function property(string memory name, string memory value)
        internal
        pure
        returns (string memory)
    {
        return string.concat('"', name, '":"', value, '"');
    }
}
