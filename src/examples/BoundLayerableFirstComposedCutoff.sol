// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerable} from '../BoundLayerable.sol';

/**
 * @notice BoundLayerable contract that keeps track of (roughly) when a base token first had its active layers
 *         set on-chain (was "composed"). This is compared against an immutable cutoff time to determine if
 *         getBoundLayerBitMap will include an exclusive extra layer.
 */
abstract contract BoundLayerableFirstComposedCutoff is BoundLayerable {
    uint256 immutable TRUNCATED_FIRST_COMPOSED_CUTOFF;
    uint8 constant EXCLUSIVE_LAYER_ID = 255;
    uint8 constant TIMESTAMP_BITS_TO_TRUNCATE = 16;
    uint256 private constant _BITPOS_EXTRA_DATA = 232;

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint240 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId,
        address _metadataContractAddress,
        uint256 _bindCutoffTimestamp
    )
        BoundLayerable(
            name,
            symbol,
            vrfCoordinatorAddress,
            maxNumSets,
            numTokensPerSet,
            subscriptionId,
            _metadataContractAddress
        )
    {
        TRUNCATED_FIRST_COMPOSED_CUTOFF = uint256(
            uint24(_bindCutoffTimestamp >> TIMESTAMP_BITS_TO_TRUNCATE)
        );
    }

    /// @dev Override _setActiveLayers to also set the
    function _setActiveLayers(uint256 baseTokenId, uint256 packedActivelayers)
        internal
        override
    {
        super._setActiveLayers(baseTokenId, packedActivelayers);
        uint256 packed = _getPackedOwnershipOf(baseTokenId);
        if (packed >> _BITPOS_EXTRA_DATA == 0) {
            uint256 truncatedTimeStamp = (block.timestamp >>
                TIMESTAMP_BITS_TO_TRUNCATE) & 0xFFFFFF;
            packed = packed | (truncatedTimeStamp << _BITPOS_EXTRA_DATA);
            _setPackedOwnershipOf(baseTokenId, packed);
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
        uint256 truncatedBoundTimestamp = _getExtraDataAt(tokenId);
        // if not set, short-circuit
        if (truncatedBoundTimestamp == 0) {
            return bindings;
        }
        // place immutable variables on stack
        uint256 numTokensPerSet = NUM_TOKENS_PER_SET;
        uint256 truncatedFirstComposedCutoffTimestamp = TRUNCATED_FIRST_COMPOSED_CUTOFF;
        assembly {
            // OR bindings with exclusive layer bit if eligible
            bindings := or(
                // use EXCLUSIVE_LAYER_ID as bit shift value for a 1-bit bool if token is eligible
                shl(
                    EXCLUSIVE_LAYER_ID,
                    // check both that tokenId is a base layer, and was composed before cutoff; will equal 1 if both are true
                    and(
                        // check tokenId is base layer since ERC721A will copy extraData when filling layer packedOwnerships
                        iszero(mod(tokenId, numTokensPerSet)),
                        // check that truncatedBoundTimeStamp occurred before truncated cutoff timestamp
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
