// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerable} from 'bound-layerable/BoundLayerable.sol';
import {BoundLayerableVariations} from 'bound-layerable/BoundLayerableVariations.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraitsImpl} from 'bound-layerable/traits/RandomTraitsImpl.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';

contract BoundLayerableVariationsTestImpl is
    BoundLayerableVariations,
    RandomTraitsImpl
{
    uint256 private constant BITMASK_BURNED = 1 << 224;

    constructor()
        BoundLayerableVariations('', '', address(1234), 5555, 7, 1, address(0))
    {
        layerVariations.push(LayerVariation(4, 4));
        layerVariations.push(LayerVariation(200, 8));
        packedBatchRandomness = bytes32(uint256(1));
        for (uint256 i; i < 8; ++i) {
            uint256 dist;
            for (uint256 j; j < 32; ++j) {
                dist |= 1 << (256 - (j + 1) * 8);
            }
            layerTypeToPackedDistributions[getLayerType(i)] = dist;
        }
        metadataContract = new ImageLayerable('default', msg.sender);
    }

    function setPackedBatchRandomness(bytes32 seed) public {
        packedBatchRandomness = seed;
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

    function unpackLayersToBitMapAndCheckForDuplicates(uint256 packedLayers)
        public
        virtual
        returns (uint256, uint256)
    {
        return _unpackLayersToBitMapAndCheckForDuplicates(packedLayers);
    }

    function getActiveLayersRaw(uint256 tokenId) public view returns (uint256) {
        return _tokenIdToPackedActiveLayers[tokenId];
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
        return tokenId + 1;
    }

    function getLayerId(uint256 tokenId, bytes32 seed)
        internal
        view
        override
        returns (uint256)
    {
        super.getLayerId(tokenId, seed);
        return tokenId + 1;
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
