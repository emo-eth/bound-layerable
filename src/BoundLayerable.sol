// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';
import {PackedByteUtility} from './lib/PackedByteUtility.sol';
import {BitMapUtility} from './lib/BitMapUtility.sol';
import {LayerVariation} from './interface/Structs.sol';
import {ILayerable} from './metadata/ILayerable.sol';
import {Layerable} from './metadata/Layerable.sol';

import {RandomTraits} from './traits/RandomTraits.sol';
import {ERC721A} from './token/ERC721A.sol';

import './interface/Errors.sol';
import {NOT_0TH_BITMASK, DUPLICATE_ACTIVE_LAYERS_SIGNATURE, LAYER_NOT_BOUND_TO_TOKEN_ID_SIGNATURE} from './interface/Constants.sol';
import {BoundLayerableEvents} from './interface/Events.sol';
import {LayerType} from './interface/Enums.sol';

abstract contract BoundLayerable is RandomTraits, BoundLayerableEvents {
    using BitMapUtility for uint256;

    mapping(uint256 => uint256) internal _tokenIdToBoundLayers;
    mapping(uint256 => uint256) internal _tokenIdToPackedActiveLayers;

    ILayerable public metadataContract;

    // TODO: incorporate modifier, compare gas
    modifier onlyBase(uint256 tokenId) {
        if (tokenId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint256 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId,
        ILayerable _metadataContract
    )
        RandomTraits(
            name,
            symbol,
            vrfCoordinatorAddress,
            maxNumSets,
            numTokensPerSet,
            subscriptionId
        )
    {
        metadataContract = _metadataContract;
    }

    /////////////
    // GETTERS //
    /////////////

    /// @notice get the layerIds currently bound to a tokenId
    function getBoundLayers(uint256 tokenId)
        external
        view
        returns (uint256[] memory)
    {
        // TODO: test doesn't return 0
        return
            BitMapUtility.unpackBitMap(
                _tokenIdToBoundLayers[tokenId] & NOT_0TH_BITMASK
            );
    }

    /// @notice get the layerIds currently active on a tokenId
    function getActiveLayers(uint256 tokenId)
        external
        view
        returns (uint256[] memory)
    {
        uint256 activePackedLayers = _tokenIdToPackedActiveLayers[tokenId];
        return PackedByteUtility.unpackByteArray(activePackedLayers);
    }

    function _tokenURI(uint256 tokenId) internal view returns (string memory) {
        return
            metadataContract.getTokenURI(
                tokenId,
                _tokenIdToBoundLayers[tokenId],
                PackedByteUtility.unpackByteArray(
                    _tokenIdToPackedActiveLayers[tokenId]
                ),
                traitGenerationSeed
            );
    }

    /////////////
    // SETTERS //
    /////////////

    /// @notice set the address of the metadata contract. OnlyOwner
    /// @param _metadataContract the address of the metadata contract
    function setMetadataContract(ILayerable _metadataContract)
        external
        onlyOwner
    {
        _setMetadataContract(_metadataContract);
    }

    /**
     * @notice Bind a layer token to a base token and burn the layer token. User must own both tokens.
     * @param baseTokenId TokenID of a base token
     * @param layerTokenId TokenID of a layer token
     * emits LayersBoundToToken
     */
    function burnAndBindSingle(uint256 baseTokenId, uint256 layerTokenId)
        public
        virtual
    {
        if (
            ownerOf(baseTokenId) != msg.sender ||
            ownerOf(layerTokenId) != msg.sender
        ) {
            revert NotOwner();
        }
        bytes32 seed = traitGenerationSeed;
        uint256 baseLayerId = getLayerId(baseTokenId, seed);

        if (baseLayerId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }

        uint256 layerId = getLayerId(layerTokenId, seed);
        if (layerId % NUM_TOKENS_PER_SET == 0) {
            revert CannotBindBase();
        }

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

    /**
     * @notice Bind layer tokens to a base token and burn the layer tokens. User must own all tokens.
     * @param baseTokenId TokenID of a base token
     * @param layerTokenIds TokenID of a layer token
     * emits LayersBoundToToken
     */
    function burnAndBindMultiple(
        uint256 baseTokenId,
        uint256[] calldata layerTokenIds
    ) public virtual {
        // todo: modifier for these?
        if (ownerOf(baseTokenId) != msg.sender) {
            revert NotOwner();
        }
        bytes32 seed = traitGenerationSeed;
        uint256 baseLayerId = getLayerId(baseTokenId, seed);

        if (baseLayerId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }
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
                uint256 layerId = getLayerId(tokenId, seed);
                if (layerId % NUM_TOKENS_PER_SET == 0) {
                    revert CannotBindBase();
                }
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

    /**
     * @notice Set the active layer IDs for a base token. Layers must be bound to token
     * @param baseTokenId TokenID of a base token
     * @param packedLayerIds Ordered layer IDs packed as bytes into uint256s to set as active on the base token
     * emits ActiveLayersChanged
     */
    function setActiveLayers(uint256 baseTokenId, uint256 packedLayerIds)
        external
        virtual
    {
        if (ownerOf(baseTokenId) != msg.sender) {
            revert NotOwner();
        }
        if (baseTokenId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }
        // unpack layers into a single bitmap and check there are no duplicates
        (
            uint256 unpackedLayers,
            uint256 numLayers
        ) = _unpackLayersToBitMapAndCheckForDuplicates(packedLayerIds);
        uint256 boundLayers = _tokenIdToBoundLayers[baseTokenId];
        // check new active layers are all bound to baseTokenId
        _checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);

        // clear all bytes after last non-zero bit on packedLayerIds,
        // since unpacking to bitmap short-circuits on first zero byte
        uint256 maskedPackedLayerIds = packedLayerIds &
            (type(uint256).max << (256 - (numLayers * 8)));
        _tokenIdToPackedActiveLayers[baseTokenId] = maskedPackedLayerIds;
        emit ActiveLayersChanged(baseTokenId, maskedPackedLayerIds);
    }

    function _setBoundLayersAndEmitEvent(uint256 baseTokenId, uint256 bindings)
        internal
    {
        // 0 is not a valid layerId, so make sure it is not set on bindings.
        bindings = bindings & NOT_0TH_BITMASK;
        _tokenIdToBoundLayers[baseTokenId] = bindings;
        emit LayersBoundToToken(baseTokenId, bindings);
    }

    // CHECK //

    /**
     * @notice Unpack bytepacked layerIds and check that there are no duplicates
     * @param bytePackedLayers uint256 of packed layerIds
     * @return bitMap uint256 of unpacked layerIds
     */
    function _unpackLayersToBitMapAndCheckForDuplicates(
        uint256 bytePackedLayers
    ) internal virtual returns (uint256 bitMap, uint256 numLayers) {
        assembly {
            for {

            } lt(numLayers, 32) {
                numLayers := add(1, numLayers)
            } {
                let layer := byte(numLayers, bytePackedLayers)
                if iszero(layer) {
                    break
                }
                // put copy of bitmap on stack
                let lastBitMap := bitMap
                // OR layer into bitmap
                bitMap := or(bitMap, shl(layer, 1))
                // check equality - if equal, layer is a duplicate
                if eq(lastBitMap, bitMap) {
                    let free_mem_ptr := mload(0x40)
                    mstore(
                        free_mem_ptr,
                        // revert DuplicateActiveLayers()
                        DUPLICATE_ACTIVE_LAYERS_SIGNATURE
                    )
                    revert(free_mem_ptr, 4)
                }
            }
        }
    }

    function _checkUnpackedIsSubsetOfBound(uint256 subset, uint256 superset)
        internal
        pure
        virtual
    {
        // superset should be superset of subset, compare union to superset
        assembly {
            if iszero(eq(or(superset, subset), superset)) {
                let freeMemPtr := mload(0x40)
                mstore(
                    freeMemPtr,
                    // revert LayerNotBoundToTokenId()
                    LAYER_NOT_BOUND_TO_TOKEN_ID_SIGNATURE
                )
                revert(freeMemPtr, 4)
            }
        }
    }

    function _setMetadataContract(ILayerable _metadataContract)
        internal
        virtual
    {
        metadataContract = _metadataContract;
    }

    /////////////
    // HELPERS //
    /////////////

    /// @dev set 0th bit to 1 in order to make first binding cost cheaper for user
    function _setPlaceholderBinding(uint256 tokenId) internal {
        _tokenIdToBoundLayers[tokenId] = 1;
    }
}
