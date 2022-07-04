// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {BoundLayerable} from 'bound-layerable/BoundLayerable.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';

contract BoundLayerableTestImpl is BoundLayerable {
    uint256 private constant BITMASK_BURNED = 1 << 224;

    constructor()
        BoundLayerable('', '', new ImageLayerable('default', msg.sender))
    {
        layerVariations.push(LayerVariation(4, 4));
        layerVariations.push(LayerVariation(200, 8));
        traitGenerationSeed = bytes32(uint256(1));
        for (uint256 i; i < 8; ++i) {
            uint256 dist;
            for (uint256 j; j < 32; ++j) {
                dist |= (1 << (256 - ((j + 1) * 8)));
            }
            layerTypeToDistributions[getLayerType(i)] = dist;
        }
    }

    // TODO: add tests for these + access control
    function removeVariations() public onlyOwner {
        delete layerVariations;
    }

    function getVariations() public view returns (LayerVariation[] memory) {
        return layerVariations;
    }

    function layerIsBoundToTokenId(uint256 _boundLayers, uint256 _layer)
        public
        pure
        virtual
        returns (bool)
    {
        return _layerIsBoundToTokenId(_boundLayers, _layer);
    }

    function checkUnpackedIsSubsetOfBound(
        uint256 _unpackedLayers,
        uint256 _boundLayers
    ) public pure virtual {
        _checkUnpackedIsSubsetOfBound(_unpackedLayers, _boundLayers);
    }

    function checkForMultipleVariations(
        uint256 _unpackedLayers,
        uint256 _boundLayers
    ) public view virtual {
        _checkForMultipleVariations(_unpackedLayers, _boundLayers);
    }

    function unpackLayersToBitMapAndCheckForDuplicates(
        uint256[] calldata _packedLayers
    ) public virtual returns (uint256) {
        return _unpackLayersToBitMapAndCheckForDuplicates(_packedLayers);
    }

    function getActiveLayersRaw(uint256 _tokenId)
        public
        view
        returns (uint256[] memory)
    {
        return _tokenIdToPackedActiveLayers[_tokenId];
    }

    function getBoundLayerBitMap(uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        return _tokenIdToBoundLayers[_tokenId];
    }

    function mint() public {
        _setPlaceholderBinding(_nextTokenId() + 6);
        super._mint(msg.sender, 7);
    }

    function getLayerId(uint256 tokenId)
        public
        view
        override
        returns (uint256)
    {
        super.getLayerId(tokenId);
        return tokenId;
    }

    function getLayerId(uint256 tokenId, bytes32 seed)
        internal
        view
        override
        returns (uint256)
    {
        super.getLayerId(tokenId, seed);
        return tokenId;
    }

    function isBurned(uint256 tokenId) public view returns (bool) {
        return _isBurned(tokenId);
    }

    function setBoundLayers(uint256 tokenId, uint256 bindings) public {
        _tokenIdToBoundLayers[tokenId] = bindings;
    }

    function setBoundLayersBulk(
        uint256[] calldata tokenIds,
        uint256[] calldata bindings
    ) public {
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            _tokenIdToBoundLayers[tokenIds[i]] = bindings[i];
        }
    }
}
