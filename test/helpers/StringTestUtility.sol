// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

library StringTestUtility {
    function startsWith(string memory ref, string memory test)
        internal
        pure
        returns (bool)
    {
        bytes memory refBytes = bytes(ref);
        bytes memory testBytes = bytes(test);
        if (testBytes.length > refBytes.length) {
            return false;
        }
        for (uint256 i = 0; i < testBytes.length; ++i) {
            if (refBytes[i] != testBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function endsWith(string memory ref, string memory test)
        internal
        pure
        returns (bool)
    {
        bytes memory refBytes = bytes(ref);
        bytes memory testBytes = bytes(test);
        if (testBytes.length > refBytes.length) {
            return false;
        }
        for (uint256 i = 0; i < testBytes.length; ++i) {
            if (
                refBytes[refBytes.length - 1 - i] !=
                testBytes[testBytes.length - 1 - i]
            ) {
                return false;
            }
        }
        return true;
    }

    function countChar(string memory str, bytes1 c)
        internal
        pure
        returns (uint256)
    {
        uint256 count;
        bytes memory strBytes = bytes(str);
        for (uint256 i = 0; i < strBytes.length; ++i) {
            if (strBytes[i] == c) {
                ++count;
            }
        }
        return count;
    }

    function contains(string memory str, string memory test)
        internal
        pure
        returns (bool)
    {
        bytes memory strBytes = bytes(str);
        bytes memory testBytes = bytes(test);
        if (testBytes.length > strBytes.length) {
            return false;
        }
        uint256 strBytesLength = strBytes.length;
        uint256 testBytesLength = testBytes.length;
        for (uint256 i = 0; i < strBytesLength - testBytesLength + 1; ++i) {
            if (testBytesLength > strBytesLength - i) {
                return false;
            }
            string memory spliced = splice(str, i, strBytesLength - 1);
            bool found = startsWith(spliced, test);
            if (found) {
                return found;
            }
        }
        return false;
    }

    function contains(string memory str, bytes1 char)
        internal
        pure
        returns (bool)
    {
        return countChar(str, char) > 0;
    }

    function splice(
        string memory str,
        uint256 start,
        uint256 end
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        uint256 resultLength = end - start + 1;
        bytes memory resultBytes = new bytes(resultLength);
        for (uint256 i = 0; i < resultLength; ++i) {
            resultBytes[i] = strBytes[i + start];
        }
        return string(resultBytes);
    }

    function equals(string memory ref, string memory test)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encode(ref)) == keccak256(abi.encode(test));
    }
}
