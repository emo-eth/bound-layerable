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
        assembly {
            // TODO: test this
            if iszero(bitMap) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x20))
                return(freePtr, 0x20)
            }
            // TODO: call internal fn
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
            // update free mem pointer to be old mem ptr + 0x20 (32-byte array length) + 0x20 * numLayers (each 32-byte element)
            mstore(0x40, add(unpacked, add(0x20, mul(numLayers, 0x20))))
        }
    }

    function uintsToBitMap(uint256[] memory uints)
        internal
        pure
        returns (uint256 bitMap)
    {
        assembly {
            let uintsIndexPtr := add(uints, 0x20)
            let finalUintsIndexPtr := add(
                uintsIndexPtr,
                mul(0x20, mload(uints))
            )
            for {

            } lt(uintsIndexPtr, finalUintsIndexPtr) {
                uintsIndexPtr := add(uintsIndexPtr, 0x20)
            } {
                bitMap := or(bitMap, shl(mload(uintsIndexPtr), 1))
            }
        }
    }

    /// from: https://github.com/paulrberg/prb-math/blob/main/contracts/PRBMath.sol, ported to pure assembly
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
