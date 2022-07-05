// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface BoundLayerableEvents {
    event LayersBoundToToken(
        uint256 indexed tokenId,
        uint256 indexed boundLayersBitmap
    );

    event ActiveLayersChanged(
        uint256 indexed tokenId,
        uint256 indexed activeLayersBytearray
    );
}
