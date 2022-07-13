// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {TestToken} from 'bound-layerable/test/TestToken.sol';

import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {RandomTraits} from 'bound-layerable/traits/RandomTraits.sol';
import {ERC721Recipient} from './util/ERC721Recipient.sol';
import {LayerType} from 'bound-layerable/interface/Enums.sol';

contract TokenImpl is TestToken {
    constructor(
        string memory name,
        string memory sym,
        string memory idk
    ) TestToken(name, sym, idk) {}

    function setBoundLayersBulkNoCalldataOverhead() public {
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
        test.setPackedBatchRandomness(bytes32(uint256(1)));
    }

    function test_snapshotDisableTradingAndBurn() public {
        test.disableTrading();
    }

    function test_snapshotBulkBindLayers() public {
        test.setBoundLayersBulkNoCalldataOverhead();
    }
}
