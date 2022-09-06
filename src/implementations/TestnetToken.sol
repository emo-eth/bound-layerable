// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerable} from '../BoundLayerable.sol';
import {RandomTraitsImpl} from '../traits/RandomTraitsImpl.sol';
import {IncorrectPayment} from '../interface/Errors.sol';
import {ERC721A} from '../token/ERC721A.sol';
import {ImageLayerable} from '../metadata/ImageLayerable.sol';

contract TestnetToken is BoundLayerable, RandomTraitsImpl {
    uint256 public constant MINT_PRICE = 0 ether;

    constructor()
        BoundLayerable(
            'test',
            'TEST',
            0x6168499c0cFfCaCD319c818142124B7A15E857ab,
            1000,
            7,
            8632,
            address(0),
            16,
            bytes32(uint256(1))
        )
    {
        // metadataContract = new ImageLayerable('default', msg.sender);
    }

    modifier includesCorrectPayment(uint256 numSets) {
        if (msg.value != numSets * MINT_PRICE) {
            revert IncorrectPayment();
        }
        _;
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
}
