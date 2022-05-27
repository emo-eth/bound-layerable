// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

library PackedByteUtility {
    // TODO: return uint256s with bitmasking
    function getPackedByteFromRight(uint256 _index, uint256 _packedBytes)
        internal
        pure
        returns (uint8 result)
    {
        assembly {
            result := byte(sub(31, _index), _packedBytes)
        }
    }

    function getPackedByteFromLeft(uint256 _index, uint256 _packedBytes)
        internal
        pure
        returns (uint8 result)
    {
        assembly {
            result := byte(_index, _packedBytes)
        }
    }

    function getPackedShortFromRight(uint256 _index, uint256 _packedShorts)
        internal
        pure
        returns (uint256 result)
    {
        // TODO: investigate structs
        // 9 gas
        assembly {
            result := and(shr(mul(_index, 16), _packedShorts), 0xffff)
        }
    }

    function getPackedShortFromLeft(uint256 _index, uint256 _packedShorts)
        internal
        pure
        returns (uint256 result)
    {
        // 12 gas
        assembly {
            result := and(shr(mul(sub(16, _index), 16), _packedShorts), 0xffff)
        }
    }

    function unpackBytesToBitField(uint256 _packedBytes)
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
                let layerId := byte(i, _packedBytes)
                if iszero(layerId) {
                    break
                }
                // layerIds are 1-indexed because we're shifting 1 by the value of the byte
                unpacked := or(unpacked, shl(layerId, 1))
            }
        }
    }

    // note: this was accidentally marked public, which was causing panics in foundry debugger?
    function packBytearray(uint8[] memory bytearray)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 bytearrayLength = bytearray.length;
        uint256[] memory packed = new uint256[]((bytearrayLength - 1) / 32 + 1);
        uint256 workingWord = 0;
        for (uint256 i = 0; i < bytearrayLength; ) {
            // OR workingWord with this byte shifted by byte within the word
            workingWord |= uint256(bytearray[i]) << (8 * (31 - (i % 32)));

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
        if (bytearrayLength % 32 != 0) {
            packed[packed.length - 1] = workingWord;
        }

        return packed;
    }

    // TODO: test
    function unpackByteArrays(uint256[] memory packedByteArrays)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 packedByteArraysLength = packedByteArrays.length;
        // TODO: is uint8 more efficient in memory?
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
}
