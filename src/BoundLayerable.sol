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
import {NOT_0TH_BITMASK} from './interface/Constants.sol';
import {BoundLayerableEvents} from './interface/Events.sol';
import {LayerType} from './interface/Enums.sol';

contract BoundLayerable is RandomTraits, BoundLayerableEvents {
    using BitMapUtility for uint256;

    mapping(uint256 => uint256) internal _tokenIdToBoundLayers;
    // TODO: consider setting limit of 32 layers, only store one uint256
    mapping(uint256 => uint256) internal _tokenIdToPackedActiveLayers;
    // mapping(uint256 => uint256) internal _tokenIdToActiveLayersPacked;

    LayerVariation[] public layerVariations;
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
        uint256 numTokensPerSet,
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
        // if (tokenId % NUM_TOKENS_PER_SET != 0) {
        //     revert OnlyBase();
        // }
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
        // if (tokenId % NUM_TOKENS_PER_SET != 0) {
        //     revert OnlyBase();
        // }
        uint256 activePackedLayers = _tokenIdToPackedActiveLayers[tokenId];
        return PackedByteUtility.unpackByteArray(activePackedLayers);
        // uint256 length = unpacked.length;
        // uint256 realLength;
        // for (uint256 i; i < length; i++) {
        //     if (unpacked[i] == 0) {
        //         break;
        //     }
        //     unchecked {
        //         ++realLength;
        //     }
        // }
        // uint256[] memory layers = new uint256[](realLength);
        // for (uint256 i; i < realLength; ++i) {
        //     layers[i] = unpacked[i];
        // }
        // return layers;
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
    ) public {
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
                if (ownerOf(baseTokenId) != msg.sender) {
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
                bindings = bindings | layerIdBitMap;
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
        // check active layers do not include multiple variations of the same trait
        _checkForMultipleVariations(boundLayers, unpackedLayers);
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

    // /**
    //  * @notice Unpack bytepacked layerIds and check that there are no duplicates
    //  * @param bytePackedLayers uint256 of packed layerIds
    //  * @return bitMap uint256 of unpacked layerIds
    //  */
    // function _unpackLayersToBitMapAndCheckForDuplicates(
    //     uint256[] calldata bytePackedLayers
    // )
    //     internal
    //     virtual
    //     returns (uint256 bitMap)
    // {
    //     assembly {
    //         let bytePackedLayersFinalOffset := add(
    //             bytePackedLayers.offset,
    //             mul(0x20, bytePackedLayers.length)
    //         )
    //         for {
    //             let i := bytePackedLayers.offset
    //         } lt(i, bytePackedLayersFinalOffset) {
    //             i := add(0x20, i)
    //         } {
    //             for {
    //                 let j
    //             } lt(j, 32) {
    //                 j := add(1, j)
    //             } {
    //                 let layer := byte(j, calldataload(i))
    //                 // TODO: optimize this
    //                 if iszero(layer) {
    //                     continue
    //                 }
    //                 let lastBitMap := bitMap
    //                 bitMap := or(bitMap, shl(layer, 1))
    //                 if eq(lastBitMap, bitMap) {
    //                     let free_mem_ptr := mload(0x40)
    //                     mstore(
    //                         free_mem_ptr,
    //                         // revert DuplicateActiveLayers()
    //                         0x6411ce7500000000000000000000000000000000000000000000000000000000
    //                     )
    //                     revert(free_mem_ptr, 4)
    //                 }
    //             }
    //         }
    //     }
    // }

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
                // TODO: optimize this
                // TODO: if max 32 layers, can also return length and bitmask before storing
                if iszero(layer) {
                    break
                }
                let lastBitMap := bitMap
                bitMap := or(bitMap, shl(layer, 1))
                if eq(lastBitMap, bitMap) {
                    let free_mem_ptr := mload(0x40)
                    mstore(
                        free_mem_ptr,
                        // revert DuplicateActiveLayers()
                        0x6411ce7500000000000000000000000000000000000000000000000000000000
                    )
                    revert(free_mem_ptr, 4)
                }
            }
        }
    }

    function _checkUnpackedIsSubsetOfBound(
        uint256 unpackedLayers,
        uint256 boundLayers
    ) internal pure virtual {
        // boundLayers should be superset of unpackedLayers, compare union to boundLayers
        if (boundLayers | unpackedLayers != boundLayers) {
            revert LayerNotBoundToTokenId();
        }
    }

    // TODO: remove?
    function _checkForMultipleVariations(
        uint256 boundLayers,
        uint256 unpackedLayers
    ) internal view {
        uint256 variationsLength = layerVariations.length;
        for (uint256 i; i < variationsLength; ++i) {
            LayerVariation memory variation = layerVariations[i];
            uint256 vLayerId = variation.layerId;
            uint256 vNumVariations = variation.numVariations;
            if (_layerIsBoundToTokenId(boundLayers, vLayerId)) {
                int256 activeVariations = int256(
                    // put variation bytes at the end of the number
                    (unpackedLayers >> vLayerId) & ((1 << vNumVariations) - 1) // drop bits above numVariations by &'ing with the same number of 1s
                );
                // n&(n-1) drops least significant bit
                // valid active variation sets are powers of 2 (a single 1) or 0
                uint256 zeroIfOneOrNoneActive = uint256(
                    activeVariations & (activeVariations - 1)
                );
                if (zeroIfOneOrNoneActive != 0) {
                    revert MultipleVariationsEnabled();
                }
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

    function _layerIsBoundToTokenId(uint256 bindings, uint256 layer)
        internal
        pure
        virtual
        returns (bool isBound)
    {
        assembly {
            isBound := and(shr(layer, bindings), 1)
        }
    }

    /// @dev set 0th bit to 1 in order to make first binding cost cheaper for user
    function _setPlaceholderBinding(uint256 tokenId) internal {
        _tokenIdToBoundLayers[tokenId] = 1;
    }
}
