// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {BoundLayerable} from 'bound-layerable/BoundLayerable.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraitsImpl} from 'bound-layerable/traits/RandomTraitsImpl.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';

contract BoundLayerableTestImpl is BoundLayerable, RandomTraitsImpl {
    uint256 private constant BITMASK_BURNED = 1 << 224;

    constructor()
        BoundLayerable(
            '',
            '',
            address(1234),
            5555,
            7,
            1,
            new ImageLayerable('default', msg.sender)
        )
    {
        layerVariations.push(LayerVariation(4, 4));
        layerVariations.push(LayerVariation(200, 8));
        traitGenerationSeed = bytes32(uint256(1));
        for (uint256 i; i < 8; ++i) {
            uint256 dist;
            for (uint256 j; j < 32; ++j) {
                dist |= 1 << (256 - (j + 1) * 8);
            }
            layerTypeToDistributions[getLayerType(i)] = dist;
        }
    }

    function setTraitGenerationSeed(bytes32 _seed) public {
        traitGenerationSeed = _seed;
    }

    function getLayerType(uint256 tokenId)
        public
        view
        virtual
        override(RandomTraits, RandomTraitsImpl)
        returns (uint8)
    {
        return RandomTraitsImpl.getLayerType(tokenId);
    }

    // TODO: add tests for these + access control
    function removeVariations() public onlyOwner {
        delete layerVariations;
    }

    function getVariations() public view returns (LayerVariation[] memory) {
        return layerVariations;
    }

    function layerIsBoundToTokenId(uint256 boundLayers, uint256 layer)
        public
        pure
        virtual
        returns (bool)
    {
        return _layerIsBoundToTokenId(boundLayers, layer);
    }

    function checkUnpackedIsSubsetOfBound(
        uint256 unpackedLayers,
        uint256 boundLayers
    ) public pure virtual {
        _checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);
    }

    function checkForMultipleVariations(
        uint256 unpackedLayers,
        uint256 boundLayers
    ) public view virtual {
        _checkForMultipleVariations(unpackedLayers, boundLayers);
    }

    function unpackLayersToBitMapAndCheckForDuplicates(uint256 _packedLayers)
        public
        virtual
        returns (uint256, uint256)
    {
        return _unpackLayersToBitMapAndCheckForDuplicates(_packedLayers);
    }

    function getActiveLayersRaw(uint256 tokenId) public view returns (uint256) {
        return _tokenIdToPackedActiveLayers[tokenId];
    }

    function getBoundLayerBitMap(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return _tokenIdToBoundLayers[tokenId];
    }

    function mint() public {
        _setPlaceholderBinding(_nextTokenId());
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
