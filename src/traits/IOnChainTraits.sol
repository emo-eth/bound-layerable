// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface OnChainTraits {
    function getTraitJson(uint256 traitId)
        external
        view
        returns (string memory);
}
