// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library PackedByteUtility {
    // TODO: return uint256s with bitmasking
    function getPackedByteFromRight(uint256 index, uint256 packedBytes)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            result := byte(sub(31, index), packedBytes)
        }
    }

    function getPackedByteFromLeft(uint256 index, uint256 packedBytes)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            result := byte(index, packedBytes)
        }
    }

    function getPackedShortFromRight(uint256 index, uint256 packedShorts)
        internal
        pure
        returns (uint256 result)
    {
        // 9 gas
        assembly {
            result := and(shr(mul(index, 16), packedShorts), 0xffff)
        }
    }

    function getPackedShortFromLeft(uint256 index, uint256 packedShorts)
        internal
        pure
        returns (uint256 result)
    {
        // 12 gas
        assembly {
            result := and(shr(mul(sub(16, index), 16), packedShorts), 0xffff)
        }
    }

    function unpackBytesToBitMap(uint256 packedBytes)
        internal
        pure
        returns (uint256 unpacked)
    {
        assembly {
            for {
                let i := 0
            } lt(i, 32) {
                i := add(i, 1)
            } {
                // this is the ID of the layer, eg, 1, 5, 253
                let byteVal := byte(i, packedBytes)
                // don't count zero bytes
                if iszero(byteVal) {
                    break
                }
                // byteVals are 1-indexed because we're shifting 1 by the value of the byte
                unpacked := or(unpacked, shl(byteVal, 1))
            }
        }
    }

    function packArraysOfBytes(uint256[] memory arrayOfBytes)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 arrayOfBytesLength = arrayOfBytes.length;
        uint256[] memory packed = new uint256[](
            (arrayOfBytesLength - 1) / 32 + 1
        );
        uint256 workingWord = 0;
        for (uint256 i = 0; i < arrayOfBytesLength; ) {
            // OR workingWord with this byte shifted by byte within the word
            workingWord |= uint256(arrayOfBytes[i]) << (8 * (31 - (i % 32)));

            // if we're on the last byte of the word, store in array
            if (i % 32 == 31) {
                uint256 j = i / 32;
                packed[j] = workingWord;
                workingWord = 0;
            }
            unchecked {
                ++i;
            }
        }
        if (arrayOfBytesLength % 32 != 0) {
            packed[packed.length - 1] = workingWord;
        }

        return packed;
    }

    function packArrayOfBytes(uint256[] memory arrayOfBytes)
        internal
        pure
        returns (uint256 packed)
    {
        assembly {
            let arrayOfBytesIndexPtr := add(arrayOfBytes, 0x20)
            let arrayOfBytesLength := mload(arrayOfBytes)
            if gt(arrayOfBytesLength, 32) {
                arrayOfBytesLength := 32
            }
            let finalI := mul(8, arrayOfBytesLength)
            let i
            for {

            } lt(i, finalI) {
                arrayOfBytesIndexPtr := add(0x20, arrayOfBytesIndexPtr)
                i := add(8, i)
            } {
                packed := or(
                    packed,
                    shl(sub(248, i), mload(arrayOfBytesIndexPtr))
                )
            }
        }
    }

    // TODO: test
    function unpackByteArrays(uint256[] memory packedByteArrays)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 packedByteArraysLength = packedByteArrays.length;
        uint256[] memory unpacked = new uint256[](packedByteArraysLength * 32);
        for (uint256 i = 0; i < packedByteArraysLength; ) {
            uint256 packedByteArray = packedByteArrays[i];
            uint256 j = 0;
            for (; j < 32; ) {
                uint256 unpackedByte = getPackedByteFromLeft(
                    j,
                    packedByteArray
                );
                if (unpackedByte == 0) {
                    break;
                }
                unpacked[i * 32 + j] = unpackedByte;
                unchecked {
                    ++j;
                }
            }
            if (j < 32) {
                break;
            }
            unchecked {
                ++i;
            }
        }
        return unpacked;
    }

    function unpackByteArray(uint256 packedByteArrays)
        internal
        pure
        returns (uint256[] memory unpacked)
    {
        assembly {
            unpacked := mload(0x40)
            let unpackedIndexPtr := add(0x20, unpacked)
            let maxUnpackedIndexPtr := add(unpackedIndexPtr, mul(0x20, 32))
            let numBytes
            for {

            } lt(unpackedIndexPtr, maxUnpackedIndexPtr) {
                unpackedIndexPtr := add(0x20, unpackedIndexPtr)
                numBytes := add(1, numBytes)
            } {
                let byteVal := byte(numBytes, packedByteArrays)
                if iszero(byteVal) {
                    break
                }
                mstore(unpackedIndexPtr, byteVal)
            }
            // store the number of layers at the pointer to unpacked array
            mstore(unpacked, numBytes)
            // update free mem pointer to be old mem ptr + 0x20 (32-byte array length) + 0x20 * numLayers (each 32-byte element)
            mstore(0x40, add(unpacked, add(0x20, mul(numBytes, 0x20))))
        }
    }
}
