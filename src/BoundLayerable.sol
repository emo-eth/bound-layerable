// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
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

contract BoundLayerable is
    ERC721A,
    Ownable,
    RandomTraits(7),
    BoundLayerableEvents
{
    using BitMapUtility for uint256;
    mapping(uint256 => uint256) internal _tokenIdToBoundLayers;
    // TODO: consider setting limit of 32 layers, only store one uint256
    mapping(uint256 => uint256[]) internal _tokenIdToPackedActiveLayers;
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
        string memory _name,
        string memory _symbol,
        string memory baseUri
    ) ERC721A(_name, _symbol) {
        metadataContract = new Layerable(baseUri, msg.sender);
    }

    /////////////
    // SETTERS //
    /////////////

    /// @dev set 0th bit to 1 in order to make first binding cost cheaper for user
    function _setPlaceholderBinding(uint256 tokenId) internal {
        _tokenIdToBoundLayers[tokenId] = 1;
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
        uint256 portraitLayerId = getLayerId(baseTokenId);

        if (portraitLayerId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }

        uint256 layerId = getLayerId(layerTokenId);
        if (layerId % NUM_TOKENS_PER_SET == 0) {
            revert CannotBindBase();
        }

        uint256 bindings = _tokenIdToBoundLayers[baseTokenId];
        // always bind portrait, since it won't be set automatically
        bindings |= portraitLayerId.toBitMap();
        // TODO: necessary?
        uint256 layerIdBitMap = layerId.toBitMap();
        if ((bindings & layerIdBitMap) > 0) {
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
        uint256 portraitLayerId = getLayerId(baseTokenId);

        if (portraitLayerId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }
        uint256 bindings = _tokenIdToBoundLayers[baseTokenId] & NOT_0TH_BITMASK;
        // always bind portrait, since it won't be set automatically
        bindings |= portraitLayerId.toBitMap();
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
                uint256 layerId = getLayerId(tokenId);
                if (layerId % NUM_TOKENS_PER_SET == 0) {
                    revert CannotBindBase();
                }
                uint256 layerIdBitMap = layerId.toBitMap();
                if ((bindings & layerIdBitMap) > 0) {
                    revert LayerAlreadyBound();
                }
                bindings = (bindings | layerIdBitMap);
                // todo: check-effects-interactions?
                _burn(tokenId);
                ++i;
            }
        }
        _setBoundLayersAndEmitEvent(baseTokenId, bindings);
    }

    function setActiveLayers(uint256 _tokenId, uint256[] calldata _packedLayers)
        external
    {
        if (ownerOf(_tokenId) != msg.sender) {
            revert NotOwner();
        }
        if (_tokenId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBase();
        }
        // unpack layers into a single bitfield and check there are no duplicates
        uint256 unpackedLayers = _unpackLayersToBitMapAndCheckForDuplicates(
            _packedLayers
        );
        uint256 boundLayers = _tokenIdToBoundLayers[_tokenId];
        // check new active layers are all bound to tokenId
        _checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);
        // check active layers do not include multiple variations of the same trait
        _checkForMultipleVariations(boundLayers, unpackedLayers);

        _tokenIdToPackedActiveLayers[_tokenId] = _packedLayers;
        emit ActiveLayersChanged(_tokenId, _packedLayers);
    }

    function _setBoundLayersAndEmitEvent(uint256 baseTokenId, uint256 bindings)
        internal
    {
        // 0 is not a valid layerId, so make sure it is not set on bindings.
        bindings = bindings & NOT_0TH_BITMASK;
        _tokenIdToBoundLayers[baseTokenId] = bindings;
        emit LayersBoundToToken(baseTokenId, bindings);
    }

    // todo: use this? compare gas
    function _isBindable(uint256 layerId) internal view returns (bool) {
        return layerId % NUM_TOKENS_PER_SET == 0;
    }

    // CHECK //

    /**
     * @notice Unpack bytepacked layerIds and check that there are no duplicates
     * @param bytePackedLayers uint256 of packed layerIds
     * @return uint256 bitMap of unpacked layerIds
     */
    function _unpackLayersToBitMapAndCheckForDuplicates(
        uint256[] calldata bytePackedLayers
    ) internal virtual returns (uint256) {
        uint256 unpackedLayers;
        uint256 packedLayersArrLength = bytePackedLayers.length;
        unchecked {
            for (uint256 i; i < packedLayersArrLength; ++i) {
                uint256 packedLayers = bytePackedLayers[i];
                for (uint256 j; j < 32; ++j) {
                    uint256 layer = PackedByteUtility.getPackedByteFromLeft(
                        j,
                        packedLayers
                    );
                    if (layer == 0) {
                        break;
                    }
                    // todo: see if assembly dropping least significant 1's is more efficient here
                    if (_layerIsBoundToTokenId(unpackedLayers, layer)) {
                        revert DuplicateActiveLayers();
                    }
                    unpackedLayers |= 1 << layer;
                }
            }
        }
        return unpackedLayers;
    }

    // // tood: remove?
    function packedLayersToBitMap(uint256[] calldata bytePackedLayers)
        public
        pure
        returns (uint256)
    {
        uint256 unpackedLayers;
        uint256 packedLayersArrLength = bytePackedLayers.length;
        for (uint256 i; i < packedLayersArrLength; ++i) {
            uint256 packedLayers = bytePackedLayers[i];
            for (uint256 j; j < 32; ++j) {
                uint256 layer = PackedByteUtility.getPackedByteFromLeft(
                    j,
                    packedLayers
                );
                if (layer == 0) {
                    break;
                }
                unpackedLayers |= 1 << layer;
            }
        }
        return unpackedLayers;
    }

    function _checkUnpackedIsSubsetOfBound(
        uint256 unpackedLayers,
        uint256 boundLayers
    ) internal pure virtual {
        // boundLayers should be superset of unpackedLayers, compare union to boundLayers
        if ((boundLayers | unpackedLayers) != boundLayers) {
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
            if (_layerIsBoundToTokenId(boundLayers, variation.layerId)) {
                int256 activeVariations = int256(
                    // put variation bytes at the end of the number
                    (unpackedLayers >> variation.layerId) &
                        ((1 << variation.numVariations) - 1)
                    // drop bits above numVariations by &'ing with the same number of 1s
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

    /////////////
    // GETTERS //
    /////////////

    function getBoundLayers(uint256 _tokenId)
        public
        view
        returns (uint256[] memory)
    {
        return BitMapUtility.unpackBitMap(_tokenIdToBoundLayers[_tokenId]);
    }

    function getActiveLayers(uint256 _tokenId)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory activePackedLayers = _tokenIdToPackedActiveLayers[
            _tokenId
        ];
        uint256[] memory unpacked = PackedByteUtility.unpackByteArrays(
            activePackedLayers
        );
        uint256 length = unpacked.length;
        uint256 realLength;
        for (uint256 i; i < length; i++) {
            if (unpacked[i] == 0) {
                break;
            }
            unchecked {
                ++realLength;
            }
        }
        uint256[] memory layers = new uint256[](realLength);
        for (uint256 i; i < realLength; ++i) {
            layers[i] = unpacked[i];
        }
        return layers;
    }

    function _tokenURI(uint256 tokenId) internal view returns (string memory) {
        return
            metadataContract.getTokenURI(
                tokenId,
                _tokenIdToBoundLayers[tokenId],
                traitGenerationSeed,
                _tokenIdToPackedActiveLayers[tokenId]
            );
    }

    function setMetadataContract(ILayerable _metadataContract)
        external
        onlyOwner
    {
        _setMetadataContract(_metadataContract);
    }

    function _setMetadataContract(ILayerable _metadataContract) internal {
        metadataContract = _metadataContract;
    }

    /////////////
    // HELPERS //
    /////////////

    function _layerIsBoundToTokenId(uint256 boundLayers, uint256 _layer)
        internal
        pure
        virtual
        returns (bool isBound)
    {
        assembly {
            isBound := and(shr(_layer, boundLayers), 1)
        }
    }
}
