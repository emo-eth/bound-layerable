// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '../interface/Constants.sol';

library BitMapUtility {
    /**
     * @notice Convert a byte value into a bitmap, where the bit at position val is set to 1, and all others 0
     * @param  val byte value to convert to bitmap
     * @return bitmap of val
     */
    function toBitMap(uint256 val) internal pure returns (uint256 bitmap) {
        /// @solidity memory-safe-assembly
        assembly {
            bitmap := shl(val, 1)
        }
    }

    /**
     * @notice get the intersection of two bitMaps by ANDing them together
     * @param  target first bitmap
     * @param  test second bitmap
     * @return result bitmap with only bits active in both bitmaps set to 1
     */
    function intersect(uint256 target, uint256 test)
        internal
        pure
        returns (uint256 result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := and(target, test)
        }
    }

    /**
     * @notice check if bitmap has byteVal set to 1
     * @param  target first bitmap
     * @param  byteVal bit position to check in target
     * @return result true if bitmap contains byteVal
     */
    function contains(uint256 target, uint256 byteVal)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := and(shr(byteVal, target), 1)
        }
    }

    /**
     * @notice check if union of two bitmaps is equal to the first
     * @param  superset first bitmap
     * @param  subset second bitmap
     * @return result true if superset is a superset of subset, false otherwise
     */
    function isSupersetOf(uint256 superset, uint256 subset)
        internal
        pure
        returns (bool result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := eq(superset, or(superset, subset))
        }
    }

    /**
     * @notice unpack a bitmap into an array of included byte values
     * @param  bitMap bitMap to unpack into byte values
     * @return unpacked array of byte values included in bitMap, sorted from smallest to largest
     */
    function unpackBitMap(uint256 bitMap)
        internal
        pure
        returns (uint256[] memory unpacked)
    {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(bitMap) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x20))
                return(freePtr, 0x20)
            }
            function lsb(x) -> leastSignificantBit {
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

            // set unpacked ptr to free mem
            unpacked := mload(0x40)
            // get ptr to first index of array
            let unpackedIndexPtr := add(unpacked, 0x20)

            let numLayers
            for {

            } bitMap {
                unpackedIndexPtr := add(unpackedIndexPtr, 0x20)
            } {
                // store the index of the lsb at the index in the array
                mstore(unpackedIndexPtr, lsb(bitMap))
                // drop the lsb from the bitMap
                bitMap := and(bitMap, sub(bitMap, 1))
                // increment numLayers
                numLayers := add(numLayers, 1)
            }
            // store the number of layers at the pointer to unpacked array
            mstore(unpacked, numLayers)
            // update free mem pointer to first free slot after unpacked array
            mstore(0x40, unpackedIndexPtr)
        }
    }

    /**
     * @notice pack an array of byte values into a bitmap
     * @param  uints array of byte values to pack into bitmap
     * @return bitMap of byte values
     */
    function uintsToBitMap(uint256[] memory uints)
        internal
        pure
        returns (uint256 bitMap)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // get pointer to first index of array
            let uintsIndexPtr := add(uints, 0x20)
            // get pointer to first word after final index of array
            let finalUintsIndexPtr := add(uintsIndexPtr, shl(5, mload(uints)))
            // loop until we reach the end of the array
            for {

            } lt(uintsIndexPtr, finalUintsIndexPtr) {
                uintsIndexPtr := add(uintsIndexPtr, 0x20)
            } {
                // set the bit at left-index 'uint' to 1
                bitMap := or(bitMap, shl(mload(uintsIndexPtr), 1))
            }
        }
    }

    /**
     * @notice Finds the zero-based index of the first one (right-indexed) in the binary representation of x.
     * @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
     * @param x The uint256 number for which to find the index of the most significant bit.
     * @return mostSignificantBit The index of the most significant bit as an uint256.
     * from: https://github.com/paulrberg/prb-math/blob/main/contracts/PRBMath.sol, ported to pure assembly
     */
    function msb(uint256 x) internal pure returns (uint256 mostSignificantBit) {
        /// @solidity memory-safe-assembly
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

    /**
     * @notice Finds the zero-based index of the first one (left-indexed) in the binary representation of x
     * @param x The uint256 number for which to find the index of the least significant bit.
     * @return leastSignificantBit The index of the least significant bit as an uint256.
     */
    function lsb(uint256 x)
        internal
        pure
        returns (uint256 leastSignificantBit)
    {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(x) {
                mstore(0, 0)
                return(0, 0x20)
            }
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
