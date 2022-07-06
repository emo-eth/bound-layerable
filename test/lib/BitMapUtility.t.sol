// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {BitMapUtility} from 'bound-layerable/lib/BitMapUtility.sol';

contract BitMapUtilityTest is Test {
    using BitMapUtility for uint256;
    using BitMapUtility for uint8;

    function testToBitMap(uint8 numBits) public {
        assertEq(numBits.toBitMap(), uint256(1 << numBits));
    }

    function testIsSupersetOf(uint256 superset, uint256 subset) public {
        superset |= subset;
        assertTrue(superset.isSupersetOf(subset));
    }

    function testIsSupersetOfNotSuperset(uint256 badSuperset, uint256 subset)
        public
    {
        badSuperset &= subset;
        if (badSuperset == subset) {
            if (subset != type(uint256).max) {
                subset += 1;
            } else {
                badSuperset = subset - 1;
            }
        }
        assertTrue(badSuperset != subset);
        assertFalse(badSuperset.isSupersetOf(subset));
    }

    function testUnpackBitMap(uint8 numBits) public {
        uint256[] memory bits = new uint256[](numBits);
        for (uint8 i = 0; i < numBits; ++i) {
            bits[i] = i;
        }
        uint256 bitMap = BitMapUtility.uintsToBitMap(bits);

        if (numBits == 0) {
            assertEq(bitMap, 0);
        } else {
            assertEq(bitMap, (1 << numBits) - 1);
        }

        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitMap);
        assertEq(unpacked.length, numBits);

        for (uint8 i = 0; i < numBits; ++i) {
            assertEq(unpacked[i], i);
        }
    }

    function testUnpackBitMap1and255() public {
        uint256 bitMap = (1 << 255) | 1;
        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitMap);
        assertEq(unpacked.length, 2);
        assertEq(unpacked[0], 0);
        assertEq(unpacked[1], 255);
    }

    function testUnpackBitMap32Ones() public {
        uint256 bitMap = 2**32 - 1;
        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitMap);
        assertEq(unpacked.length, 32);
        for (uint8 i = 0; i < 32; ++i) {
            assertEq(unpacked[i], i);
        }
    }

    function testUnpackOopsAllOnes() public {
        uint256 bitMap = (1 << 255) - 1;
        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitMap);
        assertEq(unpacked.length, 255);
        for (uint8 i = 0; i < 255; ++i) {
            assertEq(unpacked[i], i);
        }
    }

    function testMsb(uint8 msb, uint256 extraBits) public {
        uint256 bitMask;
        if (msb == 255) {
            bitMask = 2**256 - 1;
        } else {
            // subtract 1 from 2**(msb+1) to get bitmask for all including and below msb
            bitMask = (1 << (msb + 1)) - 1;
        }

        uint256 bitMap = ((1 << msb) | extraBits) & bitMask;
        uint256 retrievedMsb = BitMapUtility.msb(bitMap);
        assertEq(retrievedMsb, msb);
    }

    function testLsbZero() public {
        assertEq(BitMapUtility.lsb(0), 0);
    }

    function testMsbZero() public {
        assertEq(BitMapUtility.msb(0), 0);
    }

    function testLsb(uint8 lsb, uint256 extraBits) public {
        vm.assume(!(lsb == 0 && extraBits == 0));

        // set lsb to active
        // OR with extraBits
        // truncate bits below LSB by shifting and then shifting back
        uint256 bitMap = (((1 << lsb) | extraBits) >> lsb) << lsb;

        uint256 retrievedLsb = BitMapUtility.lsb(bitMap);
        assertEq(retrievedLsb, lsb);
    }

    function test_fuzzLsb(uint256 randomBits) public pure {
        BitMapUtility.lsb(randomBits);
    }

    function test_fuzzMsb(uint256 randomBits) public pure {
        BitMapUtility.msb(randomBits);
    }

    function testContains(uint8 byteVal) public {
        assertTrue(byteVal.toBitMap().contains(byteVal));
    }

    function testUintsToBitMap(uint8[256] memory bits) public {
        uint256[] memory castBits = new uint256[](bits.length);
        for (uint256 i = 0; i < bits.length; ++i) {
            castBits[i] = bits[i];
        }

        uint256 bitMap = BitMapUtility.uintsToBitMap(castBits);

        for (uint256 i = 0; i < bits.length; ++i) {
            assertTrue(bitMap.contains(bits[i]));
        }
    }
}
