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
        uint256[] memory layers = new uint256[](numLayers);
        bitFieldTemp = bitField;
        unchecked {
            for (uint256 i = 0; i < numLayers; ++i) {
                bitFieldTemp = bitFieldTemp & (bitFieldTemp - 1);
                layers[i] = bitField - bitFieldTemp;
                bitField = bitFieldTemp;
            }
        }
    }
}
