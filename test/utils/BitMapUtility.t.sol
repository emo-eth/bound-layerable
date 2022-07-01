// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {BitMapUtility} from '../../src/utils/BitMapUtility.sol';

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
            if (badSuperset != type(uint256).max) {
                badSuperset += 1;
            } else {
                badSuperset -= 1;
            }
        }
        assertTrue(badSuperset != subset);
    }

    function testUnpackBitField(uint8 numBits) public {
        // TODO: update for 0
        vm.assume(numBits > 0);
        uint256[] memory bits = new uint256[](numBits);
        for (uint8 i = 0; i < numBits; ++i) {
            bits[i] = i;
        }
        uint256 bitField = BitMapUtility.uintsToBitMap(bits);

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

    function testUnpackBitField1and255() public {
        uint256 bitField = (1 << 255) | 1;
        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitField);
        assertEq(unpacked.length, 2);
        assertEq(unpacked[0], 0);
        assertEq(unpacked[1], 255);
    }

    function testUnpackBitField32Ones() public {
        uint256 bitField = 2**32 - 1;
        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitField);
        assertEq(unpacked.length, 32);
        for (uint8 i = 0; i < 32; ++i) {
            assertEq(unpacked[i], i);
        }
    }

    function testUnpackOopsAllOnes() public {
        uint256 bitField = (1 << 255) - 1;
        uint256[] memory unpacked = BitMapUtility.unpackBitMap(bitField);
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
            bitMask = (1 << (msb + 1)) - 1;
        }

        uint256 bitField = ((1 << msb) | extraBits) & bitMask;
        uint256 retrievedMsb = BitMapUtility.msb(bitField);
        assertEq(retrievedMsb, msb);
    }

    function testLsbZero() public {
        assertEq(BitMapUtility.lsb(0), 0);
    }

    function testMsbZero() public {
        assertEq(BitMapUtility.msb(0), 0);
    }

    function testLsb(uint8 lsb, uint256 extraBits) public {
        vm.assume(lsb != 0);

        uint256 bitField = (((1 << lsb) | extraBits) >> lsb) << lsb;

        uint256 retrievedLsb = BitMapUtility.lsb(bitField);
        assertEq(retrievedLsb, lsb);
    }

    function test_fuzzLsb(uint256 randomBits) public pure {
        BitMapUtility.lsb(randomBits);
    }

    function test_fuzzMsb(uint256 randomBits) public pure {
        BitMapUtility.msb(randomBits);
    }

    function testThing() public {
        bool thing;
        assembly {
            thing := 0xf0
        }
        assertTrue(thing);
    }
}
