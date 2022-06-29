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
                bitMapTemp = bitMapTemp & (bitMapTemp - 1);
                unpacked[i] = mostSignificantBit(bitMap - bitMapTemp);
                bitMap = bitMapTemp;
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

    // todo: fuzz-test this with random uint8 and uint256;
    /// from: https://github.com/paulrberg/prb-math/blob/main/contracts/PRBMath.sol
    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return msb The index of the most significant bit as an uint256.
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        assembly {
            if iszero(lt(x, _2_128)) {
                x := shr(128, x)
                msb := add(msb, 128)
            }
            if iszero(lt(x, _2_64)) {
                x := shr(64, x)
                msb := add(msb, 64)
            }
            if iszero(lt(x, _2_32)) {
                x := shr(32, x)
                msb := add(msb, 32)
            }
            if iszero(lt(x, _2_16)) {
                x := shr(16, x)
                msb := add(msb, 16)
            }
            if iszero(lt(x, _2_8)) {
                x := shr(8, x)
                msb := add(msb, 8)
            }
            if iszero(lt(x, _2_4)) {
                x := shr(4, x)
                msb := add(msb, 4)
            }
            if iszero(lt(x, _2_2)) {
                x := shr(2, x)
                msb := add(msb, 2)
            }
            if iszero(lt(x, _2_1)) {
                // No need to shift x any more.
                msb := add(msb, 1)
            }
        }
    }
}
