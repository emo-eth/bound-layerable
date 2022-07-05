// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';

///@notice Ownable contract with restrictions on how many times an address can mint
abstract contract MaxMintable is Ownable {
    uint256 public maxMintsPerWallet;

    error MaxMintedForWallet();

    constructor(uint256 _maxMintsPerWallet) {
        maxMintsPerWallet = _maxMintsPerWallet;
    }

    modifier checkMaxMintedForWallet(uint256 quantity) {
        // get num minted from ERC721A
        uint256 numMinted = numberMinted(msg.sender);
        if (numMinted + quantity > maxMintsPerWallet) {
            revert MaxMintedForWallet();
        }
        _;
    }

    ///@notice set maxMintsPerWallet. OnlyOwner
    function setMaxMintsPerWallet(uint256 maxMints) public onlyOwner {
        maxMintsPerWallet = maxMints;
    }

    function numberMinted(address _owner) internal virtual returns (uint256);
}
