// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerable} from '../BoundLayerable.sol';

/**
 * @notice BoundLayerable contract that keeps track of (roughly) when a base token first had its active layers
 *         set on-chain (was "composed"). This is compared against an immutable cutoff time to determine if
 *         getBoundLayerBitMap will include an exclusive extra layer.
 */
abstract contract BoundLayerableFirstComposedCutoff is BoundLayerable {
    uint256 immutable FIRST_COMPOSED_CUTOFF;
    uint8 constant EXCLUSIVE_LAYER_ID = 255;

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
        FIRST_COMPOSED_CUTOFF = _bindCutoffTimestamp;
    }

    function _setBoundLayersAndEmitEvent(uint256 baseTokenId, uint256 bindings)
        internal
        virtual
        override
    {
        // automatically bind a special layer if the base token was composed before the cutoff time
        uint256 exclusiveLayerId = EXCLUSIVE_LAYER_ID;
        uint256 firstComposedCutoff = FIRST_COMPOSED_CUTOFF;
        /// @solidity memory-safe-assembly
        assembly {
            // conditionally set the exclusive layer bit if the base token is composed before cutoff
            bindings := or(
                bindings,
                shl(
                    exclusiveLayerId,
                    // 1 if timestamp is before cutoff, 0 otherwise (ie, no-op)
                    lt(timestamp(), firstComposedCutoff)
                )
            )
        }
        super._setBoundLayersAndEmitEvent(baseTokenId, bindings);
    }
}
