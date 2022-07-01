// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {OnChainTraits} from 'bound-layerable/traits/OnChainTraits.sol';
import {Attribute} from 'bound-layerable/interface/Structs.sol';
import {DisplayType} from 'bound-layerable/interface/Enums.sol';

contract OnChainTraitsTest is Test {
    OnChainTraits test;

    function setUp() public {
        test = new OnChainTraits();
    }

    function testGetTraitJson() public {
        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
        string memory expected = '{"trait_type":"test","value":"hello"}';
        string memory actual = test.getTraitJson(1);
        assertEq(abi.encode(actual), abi.encode(expected));

        test.setAttribute(2, Attribute('test', 'hello', DisplayType.Date));
        expected = '{"trait_type":"test","display_type":"date","value":"hello"}';
        actual = test.getTraitJson(2);
        assertEq(abi.encode(actual), abi.encode(expected));
    }
}
