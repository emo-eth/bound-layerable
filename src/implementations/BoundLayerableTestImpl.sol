// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerableSnapshotImpl} from './BoundLayerableSnapshotImpl.sol';
import {RandomTraitsImpl} from 'bound-layerable/traits/RandomTraitsImpl.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';

contract BoundLayerableTestImpl is BoundLayerableSnapshotImpl {
    function getLayerType(uint256 tokenId)
        public
        view
        virtual
        override(RandomTraits, RandomTraitsImpl)
        returns (uint8)
    {
        return RandomTraitsImpl.getLayerType(tokenId);
    }

    function checkUnpackedIsSubsetOfBound(
        uint256 unpackedLayers,
        uint256 boundLayers
    ) public pure virtual {
        _checkUnpackedIsSubsetOfBound(unpackedLayers, boundLayers);
    }

    function unpackLayersToBitMapAndCheckForDuplicates(uint256 packedLayers)
        public
        virtual
        returns (uint256, uint256)
    {
        return _unpackLayersToBitMapAndCheckForDuplicates(packedLayers);
    }

    function getActiveLayersRaw(uint256 tokenId)
        public
        view
        returns (uint256 activeLayers)
    {
        return _tokenIdToPackedActiveLayers[tokenId];
    }

    function getBoundLayerBitMap(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        return _tokenIdToBoundLayers[tokenId];
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
}
