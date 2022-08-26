// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerable} from 'bound-layerable/BoundLayerable.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraitsImpl} from 'bound-layerable/traits/RandomTraitsImpl.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {MAX_INT} from 'bound-layerable/interface/Constants.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';

contract BoundLayerableSnapshotImpl is BoundLayerable, RandomTraitsImpl {
    constructor()
        BoundLayerable('', '', address(1234), 5555, 7, 1, address(0))
    {
        packedBatchRandomness = bytes32(uint256(1));
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

        metadataContract = new ImageLayerable(msg.sender, 'default', 100, 100);
    }

    function setPackedBatchRandomness(bytes32 seed) public {
        packedBatchRandomness = seed;
    }

    function mint() public {
        _setPlaceholderBinding(_nextTokenId());
        _setPlaceholderActiveLayers(_nextTokenId());
        super._mint(msg.sender, 7);
    }

    function mint(uint256 numSets) public {
        uint256 nextId = _nextTokenId();
        for (uint256 i = 0; i < numSets; ++i) {
            uint256 tokenId = nextId + NUM_TOKENS_PER_SET * i;
            // _setPlaceholderBinding(nextId + tokenId);
            // _setPlaceholderActiveLayers(nextId + tokenId);
        }
        super._mint(msg.sender, 7 * numSets);
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
