// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721A} from '../token/ERC721A.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {BoundLayerable} from '../BoundLayerable.sol';
import {RandomTraits} from '../traits/RandomTraits.sol';
import {json} from '../lib/JSON.sol';
import '../interface/Errors.sol';
import {ClaimableImageLayerable} from './ClaimableImageLayerable.sol';

contract Token is Ownable, BoundLayerable {
    uint256 public constant MAX_SUPPLY = 5555;
    uint256 public constant MINT_PRICE = 0 ether;
    ClaimableImageLayerable alsoMetadata;

    // TODO: disable transferring to someone who does not own a base layer?
    constructor(string memory _name, string memory _symbol)
        BoundLayerable(_name, _symbol, new ClaimableImageLayerable(msg.sender))
    {
        alsoMetadata = ClaimableImageLayerable(address(metadataContract));
    }

    modifier includesCorrectPayment(uint256 _numSets) {
        if (msg.value != _numSets * MINT_PRICE) {
            revert IncorrectPayment();
        }
        _;
    }

    function claimOwnership() external {
        _transferOwnership(msg.sender);
        alsoMetadata.grantOwnership(msg.sender);
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
    function mintSets(uint256 _numSets)
        public
        payable
        includesCorrectPayment(_numSets)
    {
        super._mint(msg.sender, 7 * _numSets);
    }
}
