// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {ERC721A} from './token/ERC721A.sol';

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {BoundLayerable} from './utils/BoundLayerable.sol';
import {OnChainLayerable} from './utils/OnChainLayerable.sol';
import {RandomTraits} from './utils/RandomTraits.sol';
import {json} from './utils/JSON.sol';
import './utils/Errors.sol';

contract Token is Ownable, BoundLayerable {
    uint256 public constant MAX_SUPPLY = 5555;
    uint256 public constant MINT_PRICE = 0 ether;
    bool private tradingActive = true;

    // TODO: disable transferring to someone who does not own a base layer?
    constructor(
        string memory _name,
        string memory _symbol,
        string memory defaultURI
    ) BoundLayerable(_name, _symbol, defaultURI) {}

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
                // get owner of layer
                address owner_ = super.ownerOf(i);
                // "burn" layer by emitting transfer event to null address
                // note: can't use bulktransfer bc no guarantee that all layers are owned by same address
                emit Transfer(owner_, address(0), i);
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

    function _burnLayers(uint256 _start, uint256 _end) public onlyOwner {}

    function ownerOf(uint256 _tokenId) public view override returns (address) {
        // if trading layers is no longer active, report owner as null address
        // TODO: might be able to optimize this with two separate if statements
        if (_tokenId % 7 != 0 && !tradingActive) {
            return address(0);
        }
        return super.ownerOf(_tokenId);
    }

    function mintSet() public payable includesCorrectPayment(1) {
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
