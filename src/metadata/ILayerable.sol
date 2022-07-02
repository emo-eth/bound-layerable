// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ILayerable {
    function setBaseLayerURI(string calldata baseLayerURI) external;

    function setDefaultURI(string calldata baseLayerURI) external;

    function getLayerURI(uint256 layerId) external view returns (string memory);

    function getTokenSVG(uint256[] calldata activeLayers)
        external
        view
        returns (string memory);

    function getLayerTraits(uint256 bindings)
        external
        view
        returns (string memory);

    function getActiveLayerTraits(uint256[] calldata activeLayers)
        external
        view
        returns (string memory);

    function getLayerAndActiveTraits(
        uint256 bindings,
        uint256[] calldata activeLayers
    ) external view returns (string memory);

    function getTokenURI(
        uint256 layerId,
        uint256 bindings,
        bytes32 traitGenerationSeed,
        uint256[] calldata activeLayers
    ) external view returns (string memory);
}
