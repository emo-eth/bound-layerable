// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {BoundLayerable} from 'bound-layerable/BoundLayerable.sol';
import {BoundLayerableVariations} from 'bound-layerable/BoundLayerableVariations.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';
import {RandomTraitsImpl} from 'bound-layerable/traits/RandomTraitsImpl.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {MAX_INT} from 'bound-layerable/interface/Constants.sol';

contract BoundLayerableSnapshotImpl is BoundLayerable, RandomTraitsImpl {
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
        packedBatchRandomness = bytes32(uint256(1));
        for (uint256 i; i < 8; ++i) {
            uint256 dist;
            for (uint256 j; j < 32; ++j) {
                dist |= ((j + 1) * 7) << (256 - (j + 1) * 8);
            }
            layerTypeToPackedDistributions[getLayerType(i)] = dist;
        }
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
}
