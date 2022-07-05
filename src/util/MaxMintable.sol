// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';
import {ERC721A} from '../token/ERC721A.sol';

///@notice Ownable ERC721A contract with restrictions on how many times an address can mint
abstract contract MaxMintable is Ownable {
    uint256 public maxMintsPerWallet;

    error MaxMintedForWallet();

    constructor(uint256 _maxMintsPerWallet) {
        maxMintsPerWallet = _maxMintsPerWallet;
    }

    modifier checkMaxMintedForWallet(uint256 quantity) {
        // get num minted from ERC721A
        uint256 numMinted = _numberMinted(msg.sender);
        if ((numMinted + quantity) > maxMintsPerWallet) {
            revert MaxMintedForWallet();
        }
        _;
    }

    ///@notice set maxMintsPerWallet. OnlyOwner
    function setMaxMintsPerWallet(uint256 _maxMints) public onlyOwner {
        maxMintsPerWallet = _maxMints;
    }

    function _numberMinted(address _owner) internal virtual returns (uint256);
}
