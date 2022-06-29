// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

uint256 constant _2_128 = 2**128;
uint256 constant _2_64 = 2**64;
uint256 constant _2_32 = 2**32;
uint256 constant _2_16 = 2**16;
uint256 constant _2_8 = 2**8;
uint256 constant _2_4 = 2**4;
uint256 constant _2_2 = 2**2;
uint256 constant _2_1 = 2**1;

uint256 constant _128_MASK = 2**128 - 1;
uint256 constant _64_MASK = 2**64 - 1;
uint256 constant _32_MASK = 2**32 - 1;
uint256 constant _16_MASK = 2**16 - 1;
uint256 constant _8_MASK = 2**8 - 1;
uint256 constant _4_MASK = 2**4 - 1;
uint256 constant _2_MASK = 2**2 - 1;
uint256 constant _1_MASK = 2**1 - 1;

library BitMapUtility {
    function toBitMap(uint256 val) internal pure returns (uint256 bitmap) {
        assembly {
            bitmap := shl(val, 1)
        }
    }

    function intersect(uint256 target, uint256 test)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            result := and(target, test)
        }
    }

    function isSupersetOf(uint256 superset, uint256 subset)
        internal
        pure
        returns (bool result)
    {
        assembly {
            result := eq(superset, or(superset, subset))
        }
    }

    function unpackBitMap(uint256 bitMap)
        internal
        pure
        returns (uint256[] memory unpacked)
    {
        if (bitMap == 0) {
            return new uint256[](0);
        }
        uint256 numLayers = 0;
        uint256 bitMapTemp = bitMap;
        // count the number of 1's in the bit field to get the number of layers
        while (bitMapTemp != 0) {
            bitMapTemp = bitMapTemp & (bitMapTemp - 1);
            numLayers++;
        }
        // use that number to allocate a memory array
        // todo: look into assigning length of 255 and then modifying in-memory, if gas is ever a concern
        unpacked = new uint256[](numLayers);
        bitMapTemp = bitMap;
        unchecked {
            for (uint256 i = 0; i < numLayers; ++i) {
                unpacked[i] = lsb(bitMap);
                bitMap = bitMap & (bitMap - 1);
                // todo: this more roundabout way of getting LSB via MSB might be a bit more gas efficient, lol
                // bitMapTemp = bitMapTemp & (bitMapTemp - 1);
                // unpacked[i] = mostSignificantBit(bitMap - bitMapTemp);
                // bitMap = bitMapTemp;
            }
        }
    }

    function uintsToBitMap(uint256[] memory uints)
        internal
        pure
        returns (uint256)
    {
        uint256 bitMap;
        uint256 layersLength = uints.length;
        for (uint256 i; i < layersLength; ) {
            uint256 bit = uints[i];
            assembly {
                bitMap := or(bitMap, shl(bit, 1))
            }
            bitMap |= toBitMap(uints[i]);
            unchecked {
                ++i;
            }
        }
        return bitMap;
    }

    /// from: https://github.com/paulrberg/prb-math/blob/main/contracts/PRBMath.sol
    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return mostSignificantBit The index of the most significant bit as an uint256.
    function msb(uint256 x) internal pure returns (uint256 mostSignificantBit) {
        assembly {
            if iszero(lt(x, _2_128)) {
                x := shr(128, x)
                mostSignificantBit := add(mostSignificantBit, 128)
            }
            if iszero(lt(x, _2_64)) {
                x := shr(64, x)
                mostSignificantBit := add(mostSignificantBit, 64)
            }
            if iszero(lt(x, _2_32)) {
                x := shr(32, x)
                mostSignificantBit := add(mostSignificantBit, 32)
            }
            if iszero(lt(x, _2_16)) {
                x := shr(16, x)
                mostSignificantBit := add(mostSignificantBit, 16)
            }
            if iszero(lt(x, _2_8)) {
                x := shr(8, x)
                mostSignificantBit := add(mostSignificantBit, 8)
            }
            if iszero(lt(x, _2_4)) {
                x := shr(4, x)
                mostSignificantBit := add(mostSignificantBit, 4)
            }
            if iszero(lt(x, _2_2)) {
                x := shr(2, x)
                mostSignificantBit := add(mostSignificantBit, 2)
            }
            if iszero(lt(x, _2_1)) {
                // No need to shift x any more.
                mostSignificantBit := add(mostSignificantBit, 1)
            }
        }
    }

    function lsb(uint256 x)
        internal
        pure
        returns (uint256 leastSignificantBit)
    {
        if (x == 0) {
            return 0;
        }
        assembly {
            if iszero(and(x, _128_MASK)) {
                leastSignificantBit := add(leastSignificantBit, 128)
                x := shr(128, x)
            }
            if iszero(and(x, _64_MASK)) {
                leastSignificantBit := add(leastSignificantBit, 64)
                x := shr(64, x)
            }
            if iszero(and(x, _32_MASK)) {
                leastSignificantBit := add(leastSignificantBit, 32)
                x := shr(32, x)
            }
            if iszero(and(x, _16_MASK)) {
                leastSignificantBit := add(leastSignificantBit, 16)
                x := shr(16, x)
            }
            if iszero(and(x, _8_MASK)) {
                leastSignificantBit := add(leastSignificantBit, 8)
                x := shr(8, x)
            }
            if iszero(and(x, _4_MASK)) {
                leastSignificantBit := add(leastSignificantBit, 4)
                x := shr(4, x)
            }
            if iszero(and(x, _2_MASK)) {
                leastSignificantBit := add(leastSignificantBit, 2)
                x := shr(2, x)
            }
            if iszero(and(x, _1_MASK)) {
                // No need to shift x any more.
                leastSignificantBit := add(leastSignificantBit, 1)
            }
        }
    }
}
