// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

library BitFieldUtility {
    function unpackBitField(uint256 bitField)
        internal
        pure
        returns (uint256[] memory unpacked)
    {
        if (bitField == 0) {
            return new uint256[](0);
        }
        uint256 numLayers = 0;
        uint256 bitFieldTemp = bitField;
        // count the number of 1's in the bit field to get the number of layers
        while (bitFieldTemp != 0) {
            bitFieldTemp = bitFieldTemp & (bitFieldTemp - 1);
            numLayers++;
        }
        // use that number to allocate a memory array
        // todo: look into assigning length of 255 and then modifying in-memory, if gas is ever a concern
        unpacked = new uint256[](numLayers);
        bitFieldTemp = bitField;
        unchecked {
            for (uint256 i = 0; i < numLayers; ++i) {
                bitFieldTemp = bitFieldTemp & (bitFieldTemp - 1);
                unpacked[i] = mostSignificantBit(bitField - bitFieldTemp);
                bitField = bitFieldTemp;
            }
        }
    }

    function uint8sToBitField(uint8[] memory uints)
        internal
        pure
        returns (uint256)
    {
        uint256 bitField;
        uint256 layersLength = uints.length;
        for (uint256 i; i < layersLength; ++i) {
            uint8 bit = uints[i];
            bitField |= (1 << bit);
        }
        return bitField;
    }

    /// from: https://github.com/paulrberg/prb-math/blob/main/contracts/PRBMath.sol
    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return msb The index of the most significant bit as an uint256.
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        if (x >= 2**128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2**64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2**32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2**16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2**1) {
            // No need to shift x any more.
            msb += 1;
        }
    }
}
