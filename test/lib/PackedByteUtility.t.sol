// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';

contract PackedByteUtilityTest is Test {
    using PackedByteUtility for uint256;
    using PackedByteUtility for uint256[];

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

    function testPackArrayOfBytes() public {
        uint256[] memory bytearray = new uint256[](1);
        bytearray[0] = 0;
        uint256 packed = PackedByteUtility.packArrayOfBytes(bytearray);
        assertEq(packed, 0x0);

        bytearray[0] = 1;
        packed = PackedByteUtility.packArrayOfBytes(bytearray);
        assertEq(packed, 0x1 << 248);

        bytearray[0] = 2;
        packed = PackedByteUtility.packArrayOfBytes(bytearray);
        assertEq(packed, 0x2 << 248);

        bytearray[0] = 0xFF;
        packed = PackedByteUtility.packArrayOfBytes(bytearray);
        assertEq(packed, 0xFF << 248);

        bytearray = new uint256[](2);
        bytearray[0] = 1;
        bytearray[1] = 2;
        packed = PackedByteUtility.packArrayOfBytes(bytearray);
        assertEq(packed, (0x1 << 248) | (0x2 << 240));

        bytearray = new uint256[](32);
        bytearray[0] = 1;
        bytearray[31] = 2;
        packed = PackedByteUtility.packArrayOfBytes(bytearray);
        assertEq(packed, (0x1 << 248) | 2);

        bytearray = new uint256[](33);
        bytearray[0] = 1;
        bytearray[31] = 2;
        bytearray[32] = 5;
        packed = PackedByteUtility.packArrayOfBytes(bytearray);
        assertEq(packed, (0x1 << 248) | 2);
        // assertEq(packed[1], 5 << 248);
    }

    function testPackArraysOfBytes() public {
        uint256[] memory bytearray = new uint256[](1);
        bytearray[0] = 0;
        uint256[] memory packed = PackedByteUtility.packArraysOfBytes(
            bytearray
        );
        assertEq(packed.length, 1);
        assertEq(packed[0], 0x0);

        bytearray[0] = 1;
        packed = PackedByteUtility.packArraysOfBytes(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], 0x1 << 248);

        bytearray[0] = 2;
        packed = PackedByteUtility.packArraysOfBytes(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], 0x2 << 248);

        bytearray[0] = 0xFF;
        packed = PackedByteUtility.packArraysOfBytes(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], 0xFF << 248);

        bytearray = new uint256[](2);
        bytearray[0] = 1;
        bytearray[1] = 2;
        packed = PackedByteUtility.packArraysOfBytes(bytearray);
        assertEq(packed.length, 1);
        assertEq(packed[0], (0x1 << 248) | (0x2 << 240));

        bytearray = new uint256[](32);
        bytearray[0] = 1;
        bytearray[31] = 2;
        packed = PackedByteUtility.packArraysOfBytes(bytearray);
        assertEq(packed.length, 1);

        assertEq(packed[0], (0x1 << 248) | 2);

        bytearray = new uint256[](33);
        bytearray[0] = 1;
        bytearray[31] = 2;
        bytearray[32] = 5;
        packed = PackedByteUtility.packArraysOfBytes(bytearray);
        assertEq(packed.length, 2);
        assertEq(packed[0], (0x1 << 248) | 2);
        assertEq(packed[1], 5 << 248);
    }

    function testPackByteAtIndex(uint8 byteToPack, uint8 index) public {
        index %= 32;
        uint256 packed = PackedByteUtility.packByteAtIndex(
            type(uint256).max,
            byteToPack,
            index
        );
        uint256[] memory unpacked = packed.unpackByteArray();
        if (byteToPack == 0) {
            assertEq(unpacked.length, index);
        } else {
            assertEq(unpacked[index], byteToPack);
        }
    }

    function testUnpackBytesToBitmap(uint8[32] memory toPack) public {
        uint256[] memory generic = new uint256[](32);
        for (uint8 i = 0; i < 32; i++) {
            // always pack at least 1, never more than 255
            generic[i] = (toPack[i] % 255) + 1;
        }
        uint256 packed = PackedByteUtility.packArrayOfBytes(generic);
        emit log_named_uint('packed', packed);
        uint256 unpacked = PackedByteUtility.unpackBytesToBitMap(packed);
        emit log_named_uint('unpacked', unpacked);

        for (uint8 i = 0; i < 32; i++) {
            uint256 toCheck = generic[i];
            assertEq((unpacked >> toCheck) & 1, 1);
        }
    }

    function testPackArrayOfBytes(uint8[32] memory toPack) public {
        uint256[] memory generic = new uint256[](32);
        for (uint8 i = 0; i < 32; i++) {
            // always pack at least 1, never more than 255
            generic[i] = toPack[i];
        }
        uint256 packed = PackedByteUtility.packArrayOfBytes(generic);
        emit log_named_uint('packed', packed);

        for (uint8 i = 0; i < 32; i++) {
            assertEq(
                PackedByteUtility.getPackedByteFromLeft(i, packed),
                generic[i]
            );
        }
    }

    function testGetPackedByteFromLeft(uint8 toPack, uint8 index) public {
        index %= 32;
        uint256 packed = PackedByteUtility.packByteAtIndex(
            type(uint256).max,
            toPack,
            index
        );
        uint256 unpacked = PackedByteUtility.getPackedByteFromLeft(
            index,
            packed
        );
        assertEq(unpacked, toPack);
    }

    function testGetPackedByteFromRight(uint8 toPack, uint8 index) public {
        index %= 32;
        uint256 packed = PackedByteUtility.packByteAtIndex(
            type(uint256).max,
            toPack,
            31 - index
        );
        uint256 unpacked = PackedByteUtility.getPackedByteFromRight(
            index,
            packed
        );
        assertEq(unpacked, toPack);
    }
}
