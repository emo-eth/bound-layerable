// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {Token} from 'bound-layerable/test/Token.sol';

contract Deploy is Test {
    function run() public {
        vm.broadcast(0x92B381515bd4851Faf3d33A161f7967FD87B1227);
        Token token = new Token('test', 'test');
        token.mintSet();
    }
}
