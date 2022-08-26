// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {OnChainTraits} from 'bound-layerable/traits/OnChainTraits.sol';
import {Attribute} from 'bound-layerable/interface/Structs.sol';
import {DisplayType} from 'bound-layerable/interface/Enums.sol';
import {ArrayLengthMismatch} from 'bound-layerable/interface/Errors.sol';

// concrete implementation
contract OnChainTraitsImpl is OnChainTraits {
    function getAttributeJson(
        string memory properties,
        Attribute memory attribute
    ) public pure returns (string memory) {
        return _getAttributeJson(properties, attribute);
    }
}

contract OnChainTraitsTest is Test {
    OnChainTraitsImpl test;

    function setUp() public {
        test = new OnChainTraitsImpl();
    }

    function testGetLayerTraitJson() public {
        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
        string memory expected = '{"trait_type":"test","value":"hello"}';
        string memory actual = test.getLayerTraitJson(1);
        assertEq(abi.encode(actual), abi.encode(expected));

        test.setAttribute(2, Attribute('test', 'hello', DisplayType.Date));
        expected = '{"trait_type":"test","display_type":"date","value":"hello"}';
        actual = test.getLayerTraitJson(2);
        assertEq(abi.encode(actual), abi.encode(expected));

        expected = '{"trait_type":"qual test","display_type":"date","value":"hello"}';
        actual = test.getLayerTraitJson(2, 'qual');
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
        string memory actual = test.getLayerTraitJson(1);
        assertEq(bytes(actual), bytes(expected));

        expected = '{"trait_type":"test","value":"hello2"}';
        actual = test.getLayerTraitJson(2);
        assertEq(bytes(actual), bytes(expected));
    }

    function testSetAttributes_mismatch() public {
        uint256[] memory traitIds = new uint256[](2);
        traitIds[0] = 1;
        traitIds[1] = 2;
        Attribute[] memory attributes = new Attribute[](1);
        attributes[0] = Attribute('test', 'hello', DisplayType.String);
        vm.expectRevert(
            abi.encodeWithSelector(ArrayLengthMismatch.selector, 2, 1)
        );
        test.setAttributes(traitIds, attributes);
    }

    function testSetAttribute_onlyOwner(address addr) public {
        vm.assume(addr != address(this));
        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
        vm.startPrank(addr);
        vm.expectRevert(0x5fc483c5);
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
        vm.expectRevert(0x5fc483c5);
        test.setAttributes(traitIds, attributes);
    }

    function testGetAttributeJson() public {
        Attribute memory attribute = Attribute(
            'test',
            'hello',
            DisplayType.String
        );
        string memory expected = '{"value":"hello"}';
        string memory actual = test.getAttributeJson('', attribute);
        assertEq(actual, expected);
        attribute.displayType = DisplayType.Date;
        expected = '{"display_type":"date","value":"hello"}';
        actual = test.getAttributeJson('', attribute);
        assertEq(actual, expected);
        attribute.displayType = DisplayType.Number;
        expected = '{"display_type":"number","value":"hello"}';
        actual = test.getAttributeJson('', attribute);
        assertEq(actual, expected);
        attribute.displayType = DisplayType.BoostPercent;
        expected = '{"display_type":"boost_percent","value":"hello"}';
        actual = test.getAttributeJson('', attribute);
        assertEq(actual, expected);
        attribute.displayType = DisplayType.BoostNumber;
        expected = '{"display_type":"boost_number","value":"hello"}';
        actual = test.getAttributeJson('', attribute);
        assertEq(actual, expected);
    }
}
