// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';

contract PackedByteUtilityTest is Test {
    function testGetPackedBytesFromRight() public {
        uint256 bitMap = 0xff00000000000000000000000000000000000000000000000000000000000201;
        uint256 expected = 0x1;
        uint256 actual = PackedByteUtility.getPackedByteFromRight(0, bitMap);
        assertEq(actual, expected);
        expected = 0x2;
        actual = PackedByteUtility.getPackedByteFromRight(1, bitMap);
        assertEq(actual, expected);
        expected = 0x0;
        actual = PackedByteUtility.getPackedByteFromRight(2, bitMap);
        assertEq(actual, expected);
        expected = 0xff;
        actual = PackedByteUtility.getPackedByteFromRight(31, bitMap);
        assertEq(actual, expected);

        uint256 bitMapShort = 0x311;
        expected = 0x11;
        actual = PackedByteUtility.getPackedByteFromRight(0, bitMapShort);
        assertEq(actual, expected);
        expected = 0x3;
        actual = PackedByteUtility.getPackedByteFromRight(1, bitMapShort);
        assertEq(actual, expected);
        expected = 0x0;
        actual = PackedByteUtility.getPackedByteFromRight(2, bitMapShort);
        assertEq(actual, expected);
        expected = 0x0;
        actual = PackedByteUtility.getPackedByteFromRight(31, bitMapShort);
    }

    function testGetPackedBytesFromLeft() public {
        uint256 bitMap = 0x02010000000000000000000000000000000000000000000000000000000000ff;
        uint256 expected = 0x2;
        uint256 actual = PackedByteUtility.getPackedByteFromLeft(0, bitMap);

        assertEq(actual, expected);
        expected = 0x1;
        actual = PackedByteUtility.getPackedByteFromLeft(1, bitMap);
        assertEq(actual, expected);
        expected = 0x0;
        actual = PackedByteUtility.getPackedByteFromLeft(2, bitMap);
        assertEq(actual, expected);
        expected = 0xff;
        actual = PackedByteUtility.getPackedByteFromLeft(31, bitMap);
        assertEq(actual, expected);

        uint256 bitMapShort = 0x0311000000000000000000000000000000000000000000000000000000000000;
        expected = 0x3;
        actual = PackedByteUtility.getPackedByteFromLeft(0, bitMapShort);
        assertEq(actual, expected);
        expected = 0x11;
        actual = PackedByteUtility.getPackedByteFromLeft(1, bitMapShort);
        assertEq(actual, expected);
        expected = 0x0;
        actual = PackedByteUtility.getPackedByteFromLeft(2, bitMapShort);
        assertEq(actual, expected);
        expected = 0x0;
        actual = PackedByteUtility.getPackedByteFromLeft(31, bitMapShort);
    }

    function testUnpackBytes() public {
        uint256 packed = 0x0;
        uint256 expected = 0x0;
        uint256 actual = PackedByteUtility.unpackBytesToBitMap(packed);
        assertEq(actual, expected);

        // 0th byte won't actually be used: TODO: test
        packed = 1 << 248; // 0b1
        expected = 0x2; // 0b11 - 0-byte translates to 1
        actual = PackedByteUtility.unpackBytesToBitMap(packed);
        assertEq(actual, expected);

        packed = 0x2 << 248; // 0b10
        expected = 0x4; // 0b101 - 0-byte translates to 1
        actual = PackedByteUtility.unpackBytesToBitMap(packed);
        assertEq(actual, expected);

        packed = 0xFFFE << 240; // 0b11111111111111111111111111111110
        expected = 0xC0 << 248; // 0b11......1 - 0-byte translates to 1
        actual = PackedByteUtility.unpackBytesToBitMap(packed);
        assertEq(actual, expected);

        packed = 0xFFFE01 << 232; // 0b11111111111111111111111111111110
        expected = (0xC0 << 248) | 2; // 0b11......1 - 0-byte translates to 1
        actual = PackedByteUtility.unpackBytesToBitMap(packed);
        assertEq(actual, expected);

        // test identical bytes, as well as a straggling byte at the end of the array
        packed = (0xFFFF << 240) | 1;
        expected = 1 << 255;
        actual = PackedByteUtility.unpackBytesToBitMap(packed);
        assertEq(actual, expected);
    }

    function testPackBytearray() public {
        uint256[] memory bytearray = new uint256[](1);
        bytearray[0] = 0;
        uint256[] memory packed = PackedByteUtility.packBytearray(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], 0x0);

        bytearray[0] = 1;
        packed = PackedByteUtility.packBytearray(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], 0x1 << 248);

        bytearray[0] = 2;
        packed = PackedByteUtility.packBytearray(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], 0x2 << 248);

        bytearray[0] = 0xFF;
        packed = PackedByteUtility.packBytearray(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], 0xFF << 248);

        bytearray = new uint256[](2);
        bytearray[0] = 1;
        bytearray[1] = 2;
        packed = PackedByteUtility.packBytearray(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], (0x1 << 248) | (0x2 << 240));

        bytearray = new uint256[](32);
        bytearray[0] = 1;
        bytearray[31] = 2;
        packed = PackedByteUtility.packBytearray(bytearray);
        assertEq(packed.length, 1);

        assertEq(packed[0], (0x1 << 248) | 2);

        bytearray = new uint256[](33);
        bytearray[0] = 1;
        bytearray[31] = 2;
        bytearray[32] = 5;
        packed = PackedByteUtility.packBytearray(bytearray);
        assertEq(packed.length, 2);
        assertEq(packed[0], (0x1 << 248) | 2);
        assertEq(packed[1], 5 << 248);
    }
}
