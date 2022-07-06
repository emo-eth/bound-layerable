// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721A} from '../token/ERC721A.sol';

import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';
import {BoundLayerable} from '../BoundLayerable.sol';
import {RandomTraits} from '../traits/RandomTraits.sol';
import {json} from '../lib/JSON.sol';
import '../interface/Errors.sol';
import {ClaimableImageLayerable} from './ClaimableImageLayerable.sol';
import {TwoStepOwnable} from '../util/TwoStepOwnable.sol';
import {Withdrawable} from '../util/Withdrawable.sol';
import {MaxMintable} from '../util/MaxMintable.sol';
import {AllowList} from '../util/AllowList.sol';
import {ERC721A} from '../token/ERC721A.sol';
import {RandomTraitsImpl} from '../traits/RandomTraitsImpl.sol';

contract Token is
    BoundLayerable,
    RandomTraitsImpl,
    MaxMintable,
    AllowList,
    Withdrawable,
    TwoStepOwnable
{
    uint256 public constant MAX_SUPPLY = 5555;
    uint256 public constant MINT_PRICE = 0 ether;
    ClaimableImageLayerable alsoMetadata;

    // TODO: disable transferring to someone who does not own a base layer?
    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinatorAddress,
        uint240 maxNumSets,
        uint8 numTokensPerSet,
        uint64 subscriptionId,
        uint256 maxSetsPerWallet,
        bytes32 merkleRoot
    )
        BoundLayerable(
            name,
            symbol,
            vrfCoordinatorAddress,
            maxNumSets,
            numTokensPerSet,
            subscriptionId,
            new ClaimableImageLayerable(msg.sender)
        )
        AllowList(merkleRoot)
        MaxMintable(maxSetsPerWallet * numTokensPerSet)
    {
        alsoMetadata = ClaimableImageLayerable(address(metadataContract));
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
        // TODO: test this does not mess with active layers etc
        _setPlaceholderBinding(_nextTokenId());
        super._mint(msg.sender, 7);
    }

    // todo: restrict numminted
    function mintSets(uint256 numSets)
        public
        payable
        includesCorrectPayment(numSets)
    {
        super._mint(msg.sender, 7 * numSets);
    }

    function numberMinted(address minter)
        internal
        view
        override
        returns (uint256)
    {
        return _numberMinted(minter);
    }
}
