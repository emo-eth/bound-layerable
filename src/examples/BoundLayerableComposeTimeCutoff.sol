// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BoundLayerable} from '../BoundLayerable.sol';

/**
 * @notice BoundLayerable contract that keeps track of (roughly) when a base token first had its active layers
 *         set on-chain (was "composed"). This is compared against an immutable cutoff time to determine if
 *         getBoundLayerBitMap will include an exclusive extra layer.
 */
abstract contract BoundLayerableFirstComposedCutoff is BoundLayerable {
    uint256 immutable TRUNCATED_FIRST_COMPOSED_CUTOFF;

    constructor(uint256 _bindCutoffTimestamp) {
        TRUNCATED_FIRST_COMPOSED_CUTOFF = uint256(
            uint24(_bindCutoffTimestamp >> 16)
        );
    }

    function _setActiveLayers(uint256 baseTokenId, uint256 packedActivelayers)
        internal
        override
    {
        super._setActiveLayers(baseTokenId, packedActivelayers);
        uint24 extraData = _getExtraDataAt(baseTokenId);
        if (extraData == 0) {
            // truncate the 16 least significant bits (18.2 hours) off of the timestamp, giving us a "40" bit timestamp
            uint256 truncatedTimeStamp = block.timestamp >> 16;
            _setExtraDataAt(baseTokenId, uint24(truncatedTimeStamp));
        }
    }

    function getBoundLayerBitMap(uint256 tokenId)
        public
        view
        virtual
        override
        returns (uint256 bindings)
    {
        bindings = super.getBoundLayerBitMap(tokenId);
        uint256 numTokensPerSet = NUM_TOKENS_PER_SET;
        uint256 truncatedBoundTimestamp = _getExtraDataAt(tokenId);
        uint256 truncatedFirstComposedCutoffTimestamp = TRUNCATED_FIRST_COMPOSED_CUTOFF;
        assembly {
            bindings := or(
                shl(
                    255,
                    and(
                        iszero(mod(tokenId, numTokensPerSet)),
                        lt(
                            truncatedBoundTimestamp,
                            truncatedFirstComposedCutoffTimestamp
                        )
                    )
                ),
                bindings
            )
        }
    }

    /// @dev override ERC721A _extraData to keep the first-composed timestamp between transfers
    function _extraData(
        address,
        address,
        uint24 previousExtraData
    ) internal view virtual override returns (uint24) {
        return previousExtraData;
    }
}
