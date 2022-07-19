// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721A} from '../token/ERC721A.sol';

import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';
import {BoundLayerable} from '../BoundLayerable.sol';
import {json} from '../lib/JSON.sol';
import '../interface/Errors.sol';
import {ImageLayerable} from '../metadata/ImageLayerable.sol';
import {TwoStepOwnable} from 'utility-contracts/TwoStepOwnable.sol';
import {Withdrawable} from 'utility-contracts/withdrawable/Withdrawable.sol';
import {MaxMintable} from 'utility-contracts/MaxMintable.sol';
import {AllowList} from 'utility-contracts/AllowList.sol';
import {ERC721A} from '../token/ERC721A.sol';
import {RandomTraitsImpl} from '../traits/RandomTraitsImpl.sol';

contract TokenImpl is
    BoundLayerable,
    RandomTraitsImpl,
    MaxMintable,
    AllowList,
    Withdrawable,
    TwoStepOwnable
{
    uint256 public constant MINT_PRICE = 0 ether;

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint240 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId,
        uint256 maxSetsPerWallet,
        bytes32 merkleRoot,
        address layerableAddress
    )
        BoundLayerable(
            name,
            symbol,
            vrfCoordinatorAddress,
            maxNumSets,
            numTokensPerSet,
            subscriptionId,
            layerableAddress
        )
        AllowList(merkleRoot)
        MaxMintable(maxSetsPerWallet * numTokensPerSet)
    {
        // alsoMetadata = ClaimableImageLayerable(address(metadataContract));
    }

    modifier includesCorrectPayment(uint256 numSets) {
        if (msg.value != numSets * MINT_PRICE) {
            revert IncorrectPayment();
        }
        _;
    }

    function transferOwnership(address newOwner)
        public
        override(Ownable, TwoStepOwnable)
        onlyOwner
    {
        TwoStepOwnable.transferOwnership(newOwner);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721A)
        returns (string memory)
    {
        return _tokenURI(tokenId);
    }

    function mintSet() public payable includesCorrectPayment(1) {
        _setPlaceholderBinding(_nextTokenId());
        super._mint(msg.sender, NUM_TOKENS_PER_SET);
    }

    // todo: restrict numminted
    function mintSets(uint256 numSets)
        public
        payable
        includesCorrectPayment(numSets)
    {
        super._mint(msg.sender, NUM_TOKENS_PER_SET * numSets);
    }

    function _numberMinted(address minter)
        internal
        view
        override(ERC721A, MaxMintable)
        returns (uint256)
    {
        return _numberMinted(minter);
    }
}
