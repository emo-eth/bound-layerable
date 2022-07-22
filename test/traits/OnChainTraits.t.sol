// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {OnChainTraits} from 'bound-layerable/traits/OnChainTraits.sol';
import {Attribute} from 'bound-layerable/interface/Structs.sol';
import {DisplayType} from 'bound-layerable/interface/Enums.sol';

// concrete implementation
contract OnChainTraitsImpl is OnChainTraits {

}

contract OnChainTraitsTest is Test {
    OnChainTraits test;

    function setUp() public {
        test = new OnChainTraitsImpl();
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

        expected = '{"trait_type":"qual test","display_type":"date","value":"hello"}';
        actual = test.getTraitJson(2, 'qual');
        assertEq(abi.encode(actual), abi.encode(expected));
    }

    function testSetAttributes() public {
        uint256[] memory traitIds = new uint256[](2);
        traitIds[0] = 1;
        traitIds[1] = 2;
        Attribute[] memory attributes = new Attribute[](2);
        attributes[0] = Attribute('test', 'hello', DisplayType.String);
        attributes[1] = Attribute('test', 'hello2', DisplayType.String);
        test.setAttributes(traitIds, attributes);

        string memory expected = '{"trait_type":"test","value":"hello"}';
        string memory actual = test.getTraitJson(1);
        assertEq(bytes(actual), bytes(expected));

        expected = '{"trait_type":"test","value":"hello2"}';
        actual = test.getTraitJson(2);
        assertEq(bytes(actual), bytes(expected));
    }

    function testSetAttribute_onlyOwner(address addr) public {
        vm.assume(addr != address(this));
        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
        vm.startPrank(addr);
        vm.expectRevert('Ownable: caller is not the owner');
        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
    }

    function testSetAttributes_onlyOwner(address addr) public {
        vm.assume(addr != address(this));
        uint256[] memory traitIds = new uint256[](2);
        traitIds[0] = 1;
        traitIds[1] = 2;
        Attribute[] memory attributes = new Attribute[](2);
        attributes[0] = Attribute('test', 'hello', DisplayType.String);
        attributes[1] = Attribute('test', 'hello2', DisplayType.String);

        test.setAttributes(traitIds, attributes);
        vm.startPrank(addr);
        vm.expectRevert('Ownable: caller is not the owner');
        test.setAttributes(traitIds, attributes);
    }
}
