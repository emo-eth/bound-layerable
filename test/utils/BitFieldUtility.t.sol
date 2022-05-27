// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {BitFieldUtility} from "../../src/utils/BitFieldUtility.sol";

contract BitFieldUtilityTest is Test {
    function testUnpackBitField(uint8 numBits) public {
        vm.assume(numBits > 0);
        uint8[] memory bits = new uint8[](numBits);
        for (uint8 i = 0; i < numBits; ++i) {
            bits[i] = i;
        }
        uint256 bitField = BitFieldUtility.uint8sToBitField(bits);

        if (numBits == 1) {
            assertEq(bitField, 1);
        } else {
            assertEq(bitField, (1 << numBits) - 1);
        }
        uint256[] memory unpacked = BitFieldUtility.unpackBitField(bitField);
        assertEq(unpacked.length, numBits);

        for (uint8 i = 0; i < numBits; ++i) {
            assertEq(unpacked[i], i);
        }
    }

    function testUnpackBitFieldOneOne() public {
        uint256 bitField = (1 << 255) | 1;
        uint256[] memory unpacked = BitFieldUtility.unpackBitField(bitField);
        assertEq(unpacked.length, 2);
        assertEq(unpacked[0], 0);
        assertEq(unpacked[1], 255);
    }
}
