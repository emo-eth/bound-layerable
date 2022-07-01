// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {PackedByteUtility} from './PackedByteUtility.sol';
import {BitMapUtility} from './BitMapUtility.sol';
import {LayerVariation} from './Structs.sol';
import {OnChainLayerable} from './OnChainLayerable.sol';
import {RandomTraits} from './RandomTraits.sol';
import {ERC721A} from '../token/ERC721A.sol';

import './Errors.sol';
import {NOT_0TH_BITMASK} from './Constants.sol';
import {BoundLayerableEvents} from './Events.sol';

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
    OnChainLayerable public metadataContract;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseUri
    ) ERC721A(_name, _symbol) {
        metadataContract = new OnChainLayerable(baseUri, msg.sender);
    }

    /////////////
    // SETTERS //
    /////////////

    /// @dev set 0th bit to 1 in order to make first binding cost cheaper for user
    function _setPlaceholderBinding(uint256 tokenId) internal {
        _tokenIdToBoundLayers[tokenId] = 1;
    }

    function setBoundLayersBulk(
        uint256[] calldata _tokenId,
        uint256[] calldata _layers
    ) public onlyOwner {
        // TODO: check tokenIds are valid?
        uint256 tokenIdLength = _tokenId.length;
        if (tokenIdLength != _layers.length) {
            revert ArrayLengthMismatch(tokenIdLength, _layers.length);
        }
        for (uint256 i; i < tokenIdLength; ) {
            _tokenIdToBoundLayers[_tokenId[i]] = _layers[i] & NOT_0TH_BITMASK;
            unchecked {
                ++i;
            }
        }
    }

    function setBoundLayers(uint256 tokenId, uint256 bindings)
        public
        onlyOwner
    {
        _tokenIdToBoundLayers[tokenId] = bindings & NOT_0TH_BITMASK;
    }

    function burnAndBindLayer(uint256 _targetTokenId, uint256 _tokenIdToBind)
        public
    {
        if (
            ownerOf(_targetTokenId) != msg.sender ||
            ownerOf(_tokenIdToBind) != msg.sender
        ) {
            revert NotOwner();
        }
        // TODO: bulk fetch layerid
        uint256 portraitLayerId = getLayerId(_targetTokenId);

        if (portraitLayerId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBindable();
        }

        uint256 layerId = getLayerId(_tokenIdToBind);
        if (layerId % NUM_TOKENS_PER_SET == 0) {
            revert CannotBindBindable();
        }

        uint256 bindings = _tokenIdToBoundLayers[_targetTokenId];
        // always bind portrait, since it won't be set automatically
        bindings |= portraitLayerId.toBitMap();
        // TODO: necessary?
        uint256 layerIdBitMap = layerId.toBitMap();
        if ((bindings & layerIdBitMap) > 0) {
            revert LayerAlreadyBound();
        }
        // bindings = (bindings | layerIdBitMap) & NOT_0TH_BITMASK;
        // _tokenIdToBoundLayers[_targetTokenId] = bindings;
        _burn(_tokenIdToBind);
        _setBoundLayersAndEmitEvent(_targetTokenId, bindings | layerIdBitMap);
        // emit LayersBoundToToken(_targetTokenId, bindings);
    }

    function _setBoundLayersAndEmitEvent(
        uint256 _targetTokenId,
        uint256 bindings
    ) internal {
        bindings = bindings & NOT_0TH_BITMASK;
        _tokenIdToBoundLayers[_targetTokenId] = bindings;
        emit LayersBoundToToken(_targetTokenId, bindings);
    }

    function _isBindable(uint256 layerId) internal view returns (bool) {
        return layerId % NUM_TOKENS_PER_SET == 0;
    }

    function burnAndBindLayers(
        uint256 targetTokenId,
        uint256[] calldata tokenIdsToBind
    ) public {
        // todo: modifier for these?
        if (ownerOf(targetTokenId) != msg.sender) {
            revert NotOwner();
        }
        uint256 portraitLayerId = getLayerId(targetTokenId);

        if (portraitLayerId % NUM_TOKENS_PER_SET != 0) {
            revert OnlyBindable();
        }
        uint256 bindings = _tokenIdToBoundLayers[targetTokenId] &
            NOT_0TH_BITMASK;
        // always bind portrait, since it won't be set automatically
        bindings |= portraitLayerId.toBitMap();
        // todo: try to batch with arrays by LayerType, fetching distribution for type,
        // and looping over arrays of LayerType, to avoid duplicate lookups of distributions
        // todo: iterate once over array, delegating to LayerType arrays
        // then iterate over types + arrays
        // todo: look at most efficient way to code in assembly
        unchecked {
            // todo: revisit if via_ir = true
            uint256 length = tokenIdsToBind.length;
            uint256 i;
            for (; i < length; ) {
                uint256 tokenId = tokenIdsToBind[i];
                if (ownerOf(targetTokenId) != msg.sender) {
                    revert NotOwner();
                }
                uint256 layerId = getLayerId(tokenId);
                if (layerId % NUM_TOKENS_PER_SET == 0) {
                    revert CannotBindBindable();
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
        _setBoundLayersAndEmitEvent(targetTokenId, bindings);
        // _tokenIdToBoundLayers[targetTokenId] = (bindings & NOT_0TH_BITMASK);
    }

    function setActiveLayers(uint256 _tokenId, uint256[] calldata _packedLayers)
        external
    {
        // TODO: check tokenId is owned or authorized for msg.sender
        // TODO: check tokenId is bindable
        // if (ownerOf(_tokenId) != msg.sender) {
        //     revert NotOwner();
        // }
        if (_tokenId % NUM_TOKENS_PER_SET != 0) {
            revert NotBindable();
        }
        // unpack layers into a single bitfield and check there are no duplicates
        uint256 unpackedLayers = _unpackLayersAndCheckForDuplicates(
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

    // CHECK //

    function _unpackLayersAndCheckForDuplicates(
        uint256[] calldata _packedLayersArr
    ) internal virtual returns (uint256) {
        uint256 unpackedLayers;
        uint256 packedLayersArrLength = _packedLayersArr.length;
        for (uint256 i; i < packedLayersArrLength; ++i) {
            uint256 packedLayers = _packedLayersArr[i];
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
        return unpackedLayers;
    }

    function packedLayersToBitField(uint256[] calldata _packedLayersArr)
        public
        pure
        returns (uint256)
    {
        uint256 unpackedLayers;
        uint256 packedLayersArrLength = _packedLayersArr.length;
        for (uint256 i; i < packedLayersArrLength; ++i) {
            uint256 packedLayers = _packedLayersArr[i];
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

    function layersToBitField(uint8[] calldata layers)
        public
        pure
        returns (uint256)
    {
        uint256 unpackedLayers;
        uint256 layersLength = layers.length;
        for (uint256 i; i < layersLength; ++i) {
            uint8 layer = layers[i];
            if (layer == 0) {
                break;
            }
            unpackedLayers |= 1 << layer;
        }
        return unpackedLayers;
    }

    function _checkUnpackedIsSubsetOfBound(
        uint256 _unpackedLayers,
        uint256 _boundLayers
    ) internal pure virtual {
        // boundLayers should be superset of unpackedLayers
        uint256 unionSetLayers = _boundLayers | _unpackedLayers;
        if (unionSetLayers != _boundLayers) {
            revert LayerNotBoundToTokenId();
        }
    }

    function _checkForMultipleVariations(
        uint256 _boundLayers,
        uint256 _unpackedLayers
    ) internal view {
        uint256 variationsLength = layerVariations.length;
        for (uint256 i; i < variationsLength; ++i) {
            LayerVariation memory variation = layerVariations[i];
            if (_layerIsBoundToTokenId(_boundLayers, variation.layerId)) {
                int256 activeVariations = int256(
                    // put variation bytes at the end of the number
                    (_unpackedLayers >> variation.layerId) &
                        ((1 << variation.numVariations) - 1)
                    // drop bits above numVariations by &'ing with the same number of 1s
                );
                // n&(n-1) drops least significant 1
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

    function setMetadataContract(OnChainLayerable _metadataContract)
        external
        onlyOwner
    {
        _setMetadataContract(_metadataContract);
    }

    function _setMetadataContract(OnChainLayerable _metadataContract) internal {
        metadataContract = _metadataContract;
    }

    /////////////
    // HELPERS //
    /////////////

    function _layerIsBoundToTokenId(uint256 _boundLayers, uint256 _layer)
        internal
        pure
        virtual
        returns (bool isBound)
    {
        assembly {
            isBound := and(shr(_layer, _boundLayers), 1)
        }
    }
}
