// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {Token} from 'bound-layerable/test/Token.sol';
import {Layerable} from 'bound-layerable/metadata/Layerable.sol';

contract Deploy is Test {
    function run() public {
        vm.startBroadcast(0x92B381515bd4851Faf3d33A161f7967FD87B1227);
        // address coordinator;
        // uint256 chainId;
        // assembly {
        //     chainId := chainid()
        // }
        // emit log_named_uint('chainid', chainId);
        // if (chainId == 4) {
        //     coordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
        // } else if (chainId == 137) {
        //     coordinator = 0xAE975071Be8F8eE67addBC1A82488F1C24858067;
        // } else if (chainId == 80001) {
        //     coordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
        // } else {
        //     coordinator = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
        // }
        // emit log_named_address('coordinator', coordinator);
        // Token token = new Token(
        //     'test',
        //     'TEST',
        //     coordinator,
        //     8,
        //     2,
        //     8632,
        //     ~uint256(0) / 7,
        //     bytes32(0)
        // );
        // emit log_named_address('token', address(token));

        Token token = Token(0x233B68eE61A3DFe36fB673816F93244d3995a4F4);
        // layerable.setDistri
        uint256 packed;
        for (uint256 i; i < 32; i++) {
            packed |= uint256(((i + 1) * 7) << (248 - i * 8));
        }
        for (uint256 i; i < 7; i++) {
            token.setLayerTypeDistribution(uint8(i), packed);
        }
        // token.setForceUnsafeReveal(true);
        // token.mintSet();
        // // address owner = token.owner();
        // // emit log_named_address('owner', owner);
        // token.requestRandomWords(
        //     0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc
        // );

        // token.mintSet();
    }
}

// 00000000000000000000000000000000 ed7a99dd9bfff159a2a073feeb049405
