// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerable} from 'bound-layerable/BoundLayerable.sol';

import {BoundLayerableFirstComposedCutoff} from 'bound-layerable/examples/BoundLayerableFirstComposedCutoff.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraitsImpl} from 'bound-layerable/traits/RandomTraitsImpl.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {MAX_INT} from 'bound-layerable/interface/Constants.sol';
import {ERC721A} from 'bound-layerable/token/ERC721A.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';

contract BoundLayerableFirstComposedCutoffImpl is
    BoundLayerableFirstComposedCutoff,
    RandomTraitsImpl
{
    constructor()
        BoundLayerableFirstComposedCutoff(
            '',
            '',
            address(1234),
            5555,
            7,
            1,
            address(0),
            2**32,
            255
        )
    {
        for (uint256 i; i < 8; ++i) {
            uint256[2] memory dists = [uint256(0), uint256(0)];
            for (uint256 k; k < 2; ++k) {
                uint256 dist = dists[k];
                for (uint256 j; j < 16; ++j) {
                    uint256 short = (j + 1 + (16 * k)) * 2047;
                    dist = PackedByteUtility.packShortAtIndex(dist, short, j);
                    dists[k] = dist;
                }
            }
            layerTypeToPackedDistributions[getLayerType(i)] = dists;
        }
        metadataContract = new ImageLayerable(
            msg.sender,
            'default',
            100,
            100,
            'external',
            'description'
        );
    }

    function setPackedBatchRandomness(bytes32 seed) public {
        packedBatchRandomness = seed;
    }

    function mint() public {
        _setPlaceholderBinding(_nextTokenId());
        super._mint(msg.sender, 7);
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
