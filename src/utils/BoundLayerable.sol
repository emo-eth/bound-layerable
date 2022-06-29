// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {PackedByteUtility} from './PackedByteUtility.sol';
import {BitMapUtility} from './BitMapUtility.sol';
import {LayerVariation} from './Structs.sol';
import {OnChainLayerable} from './OnChainLayerable.sol';
import {RandomTraits} from './RandomTraits.sol';
import './Errors.sol';

contract BoundLayerable is Ownable, RandomTraits(7) {
    // TODO: potentially initialize at mint by setting leftmost bit; will quarter gas cost of binding layers
    mapping(uint256 => uint256) internal _tokenIdToBoundLayers;
    mapping(uint256 => uint256[]) internal _tokenIdToPackedActiveLayers;
    LayerVariation[] public layerVariations;
    OnChainLayerable public metadataContract;

    constructor(string memory baseUri) {
        metadataContract = new OnChainLayerable(baseUri, msg.sender);
    }

    /////////////
    // SETTERS //
    /////////////x`

    function bindLayersBulk(
        uint256[] calldata _tokenId,
        uint256[] calldata _layers
    ) public onlyOwner {
        // TODO: check tokenIds are valid?
        uint256 tokenIdLength = _tokenId.length;
        if (tokenIdLength != _layers.length) {
            revert ArrayLengthMismatch(tokenIdLength, _layers.length);
        }
        for (uint256 i; i < tokenIdLength; ) {
            _tokenIdToBoundLayers[_tokenId[i]] = _layers[i] & ~uint256(1);
            unchecked {
                ++i;
            }
        }
    }

    function bindLayers(uint256 _tokenId, uint256 _layers) public onlyOwner {
        // 0th bit is not a valid layer; make sure it is set to 0 with a bitmask
        _tokenIdToBoundLayers[_tokenId] = _layers & ~uint256(1);
    }

    function setActiveLayers(uint256 _tokenId, uint256[] calldata _packedLayers)
        external
    {
        // TODO: check tokenId is owned or authorized for msg.sender

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
    }

    // CHECK //

    function _unpackLayersAndCheckForDuplicates(
        uint256[] calldata _packedLayersArr
    ) internal virtual returns (uint256) {
        uint256 unpackedLayers;
        uint256 packedLayersArrLength = _packedLayersArr.length;
        for (uint256 i; i < packedLayersArrLength; ++i) {
            uint256 packedLayers = _packedLayersArr[i];
            // emit log_named_uint('packed layers', packedLayers);
            for (uint256 j; j < 32; ++j) {
                // uint8
                uint256 layer = PackedByteUtility.getPackedByteFromLeft(
                    j,
                    packedLayers
                );
                // emit log_named_uint('unpacked layer', layer);
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
