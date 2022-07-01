// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {Token} from 'bound-layerable/Token.sol';

import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {ERC721Recipient} from './utils/ERC721Recipient.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';

contract TokenImpl is Token {
    constructor(
        string memory name,
        string memory sym,
        string memory idk
    ) Token(name, sym, idk) {}

    function setBoundLayersBulkNoCalldataOverhead()
        public
    // uint256[] calldata _tokenId,
    // uint256[] calldata _layers
    // onlyOwner
    {
        // TODO: check tokenIds are valid?

        for (uint256 i; i < 5555; ) {
            _tokenIdToBoundLayers[i * 7] = 2;
            unchecked {
                ++i;
            }
        }
    }
}

contract TokenBulkBurnTest is Test, ERC721Recipient {
    TokenImpl test;
    uint8[] distributions;

    function setUp() public virtual {
        test = new TokenImpl('Test', 'test', '');
        test.mintSets(5555);
        test.setTraitGenerationSeed(bytes32(uint256(1)));
    }

    function test_snapshotDisableTradingAndBurn() public {
        test.disableTrading();
    }

    function test_snapshotBulkBindLayers() public {
        test.setBoundLayersBulkNoCalldataOverhead();
    }
}
