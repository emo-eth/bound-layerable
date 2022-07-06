// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {RandomTraits} from './RandomTraits.sol';

abstract contract RandomTraitsImpl is RandomTraits {
    /**
     * @notice Determine layer type by its token ID
     */
    function getLayerType(uint256 tokenId)
        public
        view
        virtual
        override
        returns (uint8 layerType)
    {
        uint256 numTokensPerSet = NUM_TOKENS_PER_SET;
        assembly {
            layerType := mod(tokenId, numTokensPerSet)
            if gt(layerType, 4) {
                layerType := sub(layerType, 2)
                // todo: update impl
                // layerType := 5
            }
        }
    }
}
