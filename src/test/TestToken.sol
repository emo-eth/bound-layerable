// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC721A} from '../token/ERC721A.sol';

import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';
import {BoundLayerableTestImpl} from './BoundLayerableTestImpl.sol';
import {RandomTraits} from '../traits/RandomTraits.sol';
import {json} from '../lib/JSON.sol';
import '../interface/Errors.sol';

contract TestToken is Ownable, BoundLayerableTestImpl {
    uint256 public constant MAX_SUPPLY = 5555;
    uint256 public constant MINT_PRICE = 0 ether;
    bool private tradingActive = true;

    // TODO: disable transferring to someone who does not own a base layer?
    constructor(
        string memory name,
        string memory symbol,
        string memory defaultURI
    ) {}

    modifier includesCorrectPayment(uint256 _numSets) {
        if (msg.value != _numSets * MINT_PRICE) {
            revert IncorrectPayment();
        }
        _;
    }

    function disableTrading() external onlyOwner {
        if (!tradingActive) {
            revert TradingAlreadyDisabled();
        }
        // todo: break this out if it will hit gas limit
        _burnLayers();
        // this will free up some gas!
        tradingActive = false;
    }

    function _burnLayers() private {
        // iterate over all token ids
        for (uint256 i; i < MAX_SUPPLY; ) {
            if (i % 7 != 0) {
                // "burn" layer by emitting transfer event to null address
                // note: can't use bulktransfer bc no guarantee that all layers are owned by same address
                // emit Transfer(owner_, address(0), i);
                _burn(i);
            }
            unchecked {
                ++i;
            }
        }
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

    function ownerOf(uint256) public view override returns (address) {
        return msg.sender;
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
