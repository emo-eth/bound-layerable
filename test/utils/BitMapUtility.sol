// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import {Test} from 'forge-std/Test.sol';
import {BitMapUtility} from '../../src/utils/BitMapUtility.sol';

contract BitMapUtilityTest is Test {
    function testUnpackBitField(uint8 numBits) public {
        vm.assume(numBits > 0);
        uint8[] memory bits = new uint8[](numBits);
        for (uint8 i = 0; i < numBits; ++i) {
            bits[i] = i;
        }
        uint256 bitField = BitMapUtility.uint8sToBitMap(bits);

        if (numBits == 1) {
            assertEq(bitField, 1);
        } else {
            assertEq(bitField, (1 << numBits) - 1);
        }
        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitField);
        assertEq(unpacked.length, numBits);

        for (uint8 i = 0; i < numBits; ++i) {
            assertEq(unpacked[i], i);
        }
    }

    function testUnpackBitFieldOneOne() public {
        uint256 bitField = (1 << 255) | 1;
        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitField);
        assertEq(unpacked.length, 2);
        assertEq(unpacked[0], 0);
        assertEq(unpacked[1], 255);
    }

    function testMsb(uint8 msb, uint256 extraBits) public {
        uint256 bitMask;
        if (msb == 255) {
            bitMask = 2**256 - 1;
        } else {
            bitMask = (1 << (msb + 1)) - 1;
        }

        uint256 bitField = ((1 << msb) | extraBits) & bitMask;
        uint256 retrievedMsb = BitMapUtility.mostSignificantBit(bitField);
        assertEq(retrievedMsb, msb);
    }
}
