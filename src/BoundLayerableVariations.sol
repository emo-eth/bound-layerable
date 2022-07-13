// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {LayerVariation} from './interface/Structs.sol';
import {ILayerable} from './metadata/ILayerable.sol';
import {BoundLayerable} from './BoundLayerable.sol';
import './interface/Errors.sol';
import {NOT_0TH_BITMASK, MULTIPLE_VARIATIONS_ENABLED_SIGNATURE} from './interface/Constants.sol';
import {BitMapUtility} from './lib/BitMapUtility.sol';
import {PackedByteUtility} from './lib/PackedByteUtility.sol';

/*
 * @notice: unfinished implementation that supports "versions" of bound layers, of which only one can be active at a time.
 */
abstract contract BoundLayerableVariations is BoundLayerable {
    using BitMapUtility for uint256;
    using PackedByteUtility for uint256[];

    error InvalidVariation();

    // LayerVariations encompass various states that a single layer can have (eg, colors),
    // of which only one can be active at a time
    LayerVariation[] public layerVariations;
    mapping(uint256 => uint256) public layerVariationIdsToCounts;
    bytes32 immutable LAYER_VARIATIONS_SLOT;

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint240 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId,
        ILayerable _metadataContract
    )
        BoundLayerable(
            name,
            symbol,
            vrfCoordinatorAddress,
            maxNumSets,
            numTokensPerSet,
            subscriptionId,
            _metadataContract
        )
    {
        // pre-calculate layerVa
        bytes32 _layerVariationsSlot;

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, layerVariations.slot)
            _layerVariationsSlot := keccak256(0, 0x20)
        }
        LAYER_VARIATIONS_SLOT = _layerVariationsSlot;
    }

    /////////////
    // GETTERS //
    /////////////

    /**
     * @notice Set the active layer IDs for a base token. Layers must be bound to token
     * @param baseTokenId TokenID of a base token
     * @param packedLayerIds Ordered layer IDs packed as bytes into uint256s to set as active on the base token
     * emits ActiveLayersChanged
     */
    function setActiveLayers(uint256 baseTokenId, uint256 packedLayerIds)
        external
        virtual
        override
    {
        if (ownerOf(baseTokenId) != msg.sender) {
            revert NotOwner();
        }
        if (baseTokenId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }
        // unpack layers into a single bitmap and check there are no duplicates
        // also get the number of layers in the bitmap
        (
            uint256 unpackedLayers,
            uint256 numLayers
        ) = _unpackLayersToBitMapAndCheckForDuplicates(packedLayerIds);
        uint256 bindings = _tokenIdToBoundLayers[baseTokenId];
        // check new active layers are all bound to baseTokenId
        _checkUnpackedIsSubsetOfBound(unpackedLayers, bindings);
        // check active layers do not include multiple variations of the same trait
        // _checkForMultipleVariations(bindings, unpackedLayers);
        uint256 maskedPackedLayerIds;
        // num layers can never be >32, so 256 - (numLayers * 8) can never negative-oveflow
        unchecked {
            maskedPackedLayerIds =
                packedLayerIds &
                (type(uint256).max << (256 - (numLayers * 8)));
        }
        _tokenIdToPackedActiveLayers[baseTokenId] = maskedPackedLayerIds;
        emit ActiveLayersChanged(baseTokenId, maskedPackedLayerIds);
    }

    // TODO: revisit this for checking variations
    // /**
    //  * @notice Set the active layer IDs for a base token. Layers must be bound to token
    //  * @param baseTokenId TokenID of a base token
    //  * @param layerIds Ordered layer IDs packed as bytes into uint256s to set as active on the base token
    //  * emits ActiveLayersChanged
    //  */
    // function setActiveLayers(uint256 baseTokenId, uint256[] memory layerIds)
    //     external
    //     virtual
    //     override
    // {
    //     if (ownerOf(baseTokenId) != msg.sender) {
    //         revert NotOwner();
    //     }
    //     if (baseTokenId % NUM_TOKENS_PER_SET != 0) {
    //         revert OnlyBase();
    //     }
    //     // unpack layers into a single bitmap and check there are no duplicates
    //     (
    //         uint256 unpackedLayers,
    //         uint256 numLayers
    //     ) = _unpackLayersToBitMapAndCheckForDuplicates(packedLayerIds);

    //     uint256 bindings = _tokenIdToBoundLayers[baseTokenId];
    //     // check new active layers are all bound to baseTokenId
    //     _checkUnpackedIsSubsetOfBound(unpackedLayers, bindings);
    //     // check active layers do not include multiple variations of the same trait
    //     _checkForMultipleVariations(bindings, unpackedLayers);
    //     uint256 maskedPackedLayerIds = packedLayerIds &
    //         (type(uint256).max << (256 - (numLayers * 8)));
    //     _tokenIdToPackedActiveLayers[baseTokenId] = maskedPackedLayerIds;
    //     emit ActiveLayersChanged(baseTokenId, maskedPackedLayerIds);
    // }

    /**
     * @notice Bind a layer token to a base token and burn the layer token. User must own both tokens.
     * @param baseTokenId TokenID of a base token
     * @param layerTokenId TokenID of a layer token
     * emits LayersBoundToToken
     */
    function burnAndBindSingle(uint256 baseTokenId, uint256 layerTokenId)
        public
        virtual
        override
    {
        if (
            ownerOf(baseTokenId) != msg.sender ||
            ownerOf(layerTokenId) != msg.sender
        ) {
            revert NotOwner();
        }
        bytes32 seed = packedBatchRandomness;

        if (baseTokenId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }
        uint256 baseLayerId = getLayerId(baseTokenId, seed);

        if (layerTokenId % NUM_TOKENS_PER_SET == 0) {
            revert CannotBindBase();
        }
        uint256 layerId = getLayerId(layerTokenId, seed);

        uint256 bindings = _tokenIdToBoundLayers[baseTokenId];
        // always bind baseLayer, since it won't be set automatically
        bindings |= baseLayerId.toBitMap();
        // TODO: necessary?
        uint256 layerIdBitMap = layerId.toBitMap();
        if (bindings & layerIdBitMap > 0) {
            revert LayerAlreadyBound();
        }

        _burn(layerTokenId);
        _setBoundLayersAndEmitEvent(baseTokenId, bindings | layerIdBitMap);
    }

    function getActiveVariation(uint256 variationId)
        internal
        view
        returns (uint256)
    {
        if (variationId < 256) {
            return variationId;
        }
        variationId = variationId >> 8;
        uint256 actualVariationId = variationId.lsb();
        uint256 activeVariation = (actualVariationId & (actualVariationId - 1))
            .lsb();
        uint256 numVariationActive = activeVariation == 0
            ? 0
            : activeVariation - actualVariationId;
        if (numVariationActive == 0) {
            return actualVariationId;
        }
        uint256 countValidLayerVariations = layerVariationIdsToCounts[
            actualVariationId
        ];
        if (countValidLayerVariations < numVariationActive) {
            revert InvalidVariation();
        }
        return activeVariation;
    }

    /**
     * @notice Bind layer tokens to a base token and burn the layer tokens. User must own all tokens.
     * @param baseTokenId TokenID of a base token
     * @param layerTokenIds TokenID of a layer token
     * emits LayersBoundToToken
     */
    function burnAndBindMultiple(
        uint256 baseTokenId,
        uint256[] calldata layerTokenIds
    ) public virtual override {
        // todo: modifier for these?
        if (ownerOf(baseTokenId) != msg.sender) {
            revert NotOwner();
        }
        if (baseTokenId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }

        bytes32 seed = packedBatchRandomness;
        uint256 baseLayerId = getLayerId(baseTokenId, seed);

        uint256 bindings = _tokenIdToBoundLayers[baseTokenId] & NOT_0TH_BITMASK;
        // always bind baseLayer, since it won't be set automatically
        bindings |= baseLayerId.toBitMap();
        // todo: try to batch with arrays by LayerType, fetching distribution for type,
        // and looping over arrays of LayerType, to avoid duplicate lookups of distributions
        // todo: iterate once over array, delegating to LayerType arrays
        // then iterate over types + arrays
        // todo: look at most efficient way to code in assembly
        unchecked {
            // todo: revisit if via_ir = true
            uint256 length = layerTokenIds.length;
            uint256 i;
            for (; i < length; ) {
                uint256 tokenId = layerTokenIds[i];
                if (ownerOf(tokenId) != msg.sender) {
                    revert NotOwner();
                }
                if (tokenId % NUM_TOKENS_PER_SET == 0) {
                    revert CannotBindBase();
                }
                uint256 layerId = getLayerId(tokenId, seed);

                uint256 layerIdBitMap = layerId.toBitMap();
                if (bindings & layerIdBitMap > 0) {
                    revert LayerAlreadyBound();
                }
                bindings |= layerIdBitMap;
                // todo: check-effects-interactions?
                _burn(tokenId);
                ++i;
            }
        }
        _setBoundLayersAndEmitEvent(baseTokenId, bindings);
    }

    function _checkForMultipleVariations(
        uint256 bindings,
        uint256 unpackedLayers
    ) internal view {
        bytes32 _layerVariationsSlot = LAYER_VARIATIONS_SLOT;

        /// @solidity memory-safe-assembly
        assembly {
            let variationsLength := sload(layerVariations.slot)
            let finalVariationsSlot := add(
                variationsLength,
                _layerVariationsSlot
            )
            for {

            } lt(_layerVariationsSlot, finalVariationsSlot) {
                _layerVariationsSlot := add(1, _layerVariationsSlot)
            } {
                let variation := sload(_layerVariationsSlot)
                let vLayerId := byte(31, variation)
                let vNumVariations := byte(30, variation)
                if and(shr(vLayerId, bindings), 1) {
                    let activeVariations := and(
                        shr(vLayerId, unpackedLayers),
                        sub(shl(vNumVariations, 1), 1)
                    )

                    let zeroIfOneOrNoneActive := and(
                        activeVariations,
                        sub(activeVariations, 1)
                    )
                    if zeroIfOneOrNoneActive {
                        mstore(
                            0,
                            // revert MultipleVariationsEnabled()
                            MULTIPLE_VARIATIONS_ENABLED_SIGNATURE
                        )
                        revert(0, 0x4)
                    }
                }
            }
        }
    }
}
