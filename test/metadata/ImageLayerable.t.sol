// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {Attribute} from 'bound-layerable/interface/Structs.sol';
import {DisplayType} from 'bound-layerable/interface/Enums.sol';
import {StringTestUtility} from '../helpers/StringTestUtility.sol';
import {LibString} from 'solady/utils/LibString.sol';
import {InvalidInitialization} from 'bound-layerable/interface/Errors.sol';
import {json} from 'bound-layerable/lib/JSON.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {Base64} from 'solady/utils/Base64.sol';

contract ImageLayerableImpl is ImageLayerable {
    using Strings for uint256;
    uint256 bindings;
    uint256[] activeLayers;
    bytes32 packedBatchRandomness;

    constructor()
        ImageLayerable(
            msg.sender,
            'default',
            100,
            100,
            'external',
            'description'
        )
    {}

    function setBindings(uint256 _bindings) public {
        bindings = _bindings;
    }

    function setActiveLayers(uint256[] memory _activeLayers) public {
        activeLayers = _activeLayers;
    }

    function setPackedBatchRandomness(bytes32 _packedBatchRandomness) public {
        packedBatchRandomness = _packedBatchRandomness;
    }

    function tokenJson(uint256 layerId)
        public
        view
        virtual
        returns (string memory)
    {
        return
            this.getTokenJson(
                layerId,
                layerId,
                bindings,
                activeLayers,
                packedBatchRandomness
            );
    }

    function tokenURI(uint256 layerId)
        public
        view
        virtual
        returns (string memory)
    {
        return
            this.getTokenURI(
                layerId,
                layerId,
                bindings,
                activeLayers,
                packedBatchRandomness
            );
    }

    function getWidth() public view returns (uint256) {
        return width;
    }

    function getHeight() public view returns (uint256) {
        return height;
    }

    function getDefaultURI() public view returns (string memory) {
        return defaultURI;
    }

    function getBaseLayerURI() public view returns (string memory) {
        return baseLayerURI;
    }
}

contract InitializeTester {
    constructor(address target) {
        (bool success, ) = target.delegatecall(
            abi.encodeWithSignature(
                'initialize(address,string,uint256,uint256)',
                address(5),
                'default',
                100,
                100,
                'external',
                'description'
            )
        );
        require(success, 'failed');
    }

    function readSlot(uint256 slot) public view returns (uint256 slotVal) {
        assembly {
            slotVal := sload(slot)
        }
    }
}

contract ImageLayerableTest is Test {
    using StringTestUtility for string;
    using LibString for uint256;

    ImageLayerableImpl test;

    function setUp() public {
        test = new ImageLayerableImpl();
        test.setBaseLayerURI('layer/');
    }

    function toBase64URI(string memory tokenJson)
        public
        view
        virtual
        returns (string memory)
    {
        return
            string.concat(
                'data:application/json;base64,',
                Base64.encode(bytes(tokenJson))
            );
    }

    function testGetTokenURI() public {
        // no seed means default metadata
        string memory tokenJson = test.tokenJson(0);
        string memory expected = toBase64URI(tokenJson);
        string memory actual = test.tokenURI(0);
        assertEq(actual, expected);
        test.setPackedBatchRandomness(bytes32(uint256(1)));

        // // once seeded, if not bound, regular nft metadata
        // // test.setPackedBatchRandomness(bytes32(uint256(1)));
        // expected = 'data:application/json;base64,eyJpbWFnZSI6ImxheWVyLzEiLCJhdHRyaWJ1dGVzIjpbeyJ0cmFpdF90eXBlIjoiTGF5ZXIgVHlwZSIsInZhbHVlIjoidGVzdCJ9LHsidHJhaXRfdHlwZSI6InRlc3QiLCJ2YWx1ZSI6ImhlbGxvIn1dfQ==';
        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
        test.setAttribute(2, Attribute('test2', 'hello2', DisplayType.Number));
        tokenJson = test.tokenJson(1);
        expected = toBase64URI(tokenJson);
        actual = test.tokenURI(1);
        assertEq(actual, expected);

        // once bound, show layers
        uint256 boundLayers = 3 << 1;
        test.setBindings(boundLayers);
        // test.bindLayers(0, 3 << 1);
        // no active layers
        tokenJson = test.tokenJson(1);
        expected = toBase64URI(tokenJson);
        actual = test.tokenURI(1);
        assertEq(actual, expected);
        uint256[] memory activeLayers = new uint256[](2);
        // activeLayers[0] = (0x02 << 248) | (0x01 << 240);
        activeLayers[0] = 2;
        activeLayers[1] = 1;

        test.setActiveLayers(activeLayers);
        tokenJson = test.tokenJson(1);
        expected = toBase64URI(tokenJson);
        actual = test.tokenURI(1);
        assertEq(actual, expected);
    }

    function testGetTokenJson1() public {
        // no seed means default metadata
        string[] memory properties = new string[](2);
        properties[0] = json.property('name', uint256(0).toString());
        properties[1] = json.property('image', 'default');
        string memory expected = json.objectOf(properties);

        string memory actual = test.tokenJson(0);
        assertEq(actual, expected);
        test.setPackedBatchRandomness(bytes32(uint256(1)));

        // once seeded, if not bound, regular nft metadata
        // test.setPackedBatchRandomness(bytes32(uint256(1)));
        Attribute memory attribute1 = Attribute(
            'test',
            'hello',
            DisplayType.String
        );
        Attribute memory attribute2 = Attribute(
            'test2',
            'hello2',
            DisplayType.Number
        );
        test.setAttribute(1, attribute1);
        test.setAttribute(2, attribute2);
        properties = new string[](3);
        properties[0] = json.property('name', uint256(1).toString());
        properties[1] = json.property('image', 'layer/1');
        string[] memory attributes = new string[](2);
        attributes[0] = _attributeString(
            Attribute('Layer Type', 'test', DisplayType.String)
        );
        attributes[1] = _attributeString(attribute1);

        properties[2] = json.rawProperty(
            'attributes',
            json.arrayOf(attributes)
        );
        expected = json.objectOf(properties);
        actual = test.tokenJson(1);
        assertEq(actual, expected);

        // once bound, show layers
        uint256 boundLayers = 3 << 1;
        test.setBindings(boundLayers);
        // test.bindLayers(0, 3 << 1);
        // no active layers
        properties[1] = json.property(
            'image',
            'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMTAwIiAgd2lkdGg9IjEwMCIgPjwvc3ZnPg=='
        );
        attributes = new string[](3);
        attributes[0] = _attributeString(attribute1);
        attributes[1] = _attributeString(attribute2);
        attributes[2] = _attributeString(
            Attribute('Layer Count', '2', DisplayType.Number)
        );
        properties[2] = json.rawProperty(
            'attributes',
            json.arrayOf(attributes)
        );
        expected = json.objectOf(properties);
        actual = test.tokenJson(1);
        assertEq(actual, expected);

        uint256[] memory activeLayers = new uint256[](2);
        // activeLayers[0] = (0x02 << 248) | (0x01 << 240);
        activeLayers[0] = 2;
        activeLayers[1] = 1;

        test.setActiveLayers(activeLayers);
        properties[1] = json.property(
            'image',
            'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMTAwIiAgd2lkdGg9IjEwMCIgPjxpbWFnZSBocmVmPSJsYXllci8yIiAgaGVpZ2h0PSIxMDAlIiAgd2lkdGg9IjEwMCUiIC8+PGltYWdlIGhyZWY9ImxheWVyLzEiICBoZWlnaHQ9IjEwMCUiICB3aWR0aD0iMTAwJSIgLz48L3N2Zz4='
        );
        attributes = new string[](5);
        attributes[0] = _attributeString(attribute1);
        attributes[1] = _attributeString(attribute2);
        attributes[2] = _attributeString(
            Attribute('Layer Count', '2', DisplayType.Number)
        );
        attributes[3] = _attributeString(
            Attribute('Active test2', attribute2.value, attribute2.displayType)
        );
        attributes[4] = _attributeString(
            Attribute('Active test', attribute1.value, attribute1.displayType)
        );
        properties[2] = json.rawProperty(
            'attributes',
            json.arrayOf(attributes)
        );
        expected = json.objectOf(properties);
        // expected = '{"image":"data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMTAwIiAgd2lkdGg9IjEwMCIgPjxpbWFnZSBocmVmPSJsYXllci8yIiAgaGVpZ2h0PSIxMDAlIiAgd2lkdGg9IjEwMCUiIC8+PGltYWdlIGhyZWY9ImxheWVyLzEiICBoZWlnaHQ9IjEwMCUiICB3aWR0aD0iMTAwJSIgLz48L3N2Zz4=","attributes":[{"trait_type":"test","value":"hello"},{"trait_type":"test2","display_type":"number","value":"hello2"},{"trait_type":"Layer Count","display_type":"number","value":"2"},{"trait_type":"Active test2","display_type":"number","value":"hello2"},{"trait_type":"Active test","value":"hello"}]}';
        actual = test.tokenJson(1);
        assertEq(actual, expected);
    }

    function _attributeString(Attribute memory attribute)
        internal
        pure
        returns (string memory)
    {
        string[] memory properties;
        if (attribute.displayType == DisplayType.Number) {
            properties = new string[](3);
            properties[0] = json.property('trait_type', attribute.traitType);
            properties[1] = json.property('display_type', 'number');
            properties[2] = json.property('value', attribute.value);
        } else {
            properties = new string[](2);
            properties[0] = json.property('trait_type', attribute.traitType);
            properties[1] = json.property('value', attribute.value);
        }
        return json.objectOf(properties);
    }

    function testGetTokenJson(uint256 layerId) public {
        // no seed means default metadata
        string[] memory properties = new string[](2);
        properties[0] = json.property('name', uint256(layerId).toString());
        properties[1] = json.property('image', 'default');
        string memory expected = json.objectOf(properties);
        string memory actual = test.tokenJson(layerId);

        assertEq(actual, expected);
        test.setPackedBatchRandomness(bytes32(uint256(1)));
        properties = new string[](3);
        properties[0] = json.property('name', layerId.toString());
        properties[1] = json.property(
            'image',
            string.concat('layer/', layerId.toString())
        );
        Attribute memory attribute = Attribute(
            'test',
            'hello',
            DisplayType.String
        );
        string[] memory attributes = new string[](2);
        attributes[0] = _attributeString(
            Attribute('Layer Type', 'test', DisplayType.String)
        );
        attributes[1] = _attributeString(attribute);
        properties[2] = json.rawProperty(
            'attributes',
            json.arrayOf(attributes)
        );
        expected = json.objectOf(properties);

        test.setAttribute(
            layerId,
            Attribute('test', 'hello', DisplayType.String)
        );
        actual = test.tokenJson(layerId);
        assertEq(actual, expected);
        test.setBindings(1);
        actual = test.tokenJson(layerId);
        assertEq(actual, expected);
    }

    function testGetLayerJson(uint256 layerId) public {
        string[] memory properties = new string[](3);
        properties[0] = json.property('name', layerId.toString());
        properties[1] = json.property(
            'image',
            string.concat('layer/', layerId.toString())
        );
        Attribute memory attribute1 = Attribute(
            'Layer Type',
            'test',
            DisplayType.String
        );
        Attribute memory attribute2 = Attribute(
            'test',
            'hello',
            DisplayType.String
        );
        string[] memory attributes = new string[](2);
        attributes[0] = _attributeString(attribute1);
        attributes[1] = _attributeString(attribute2);
        properties[2] = json.rawProperty(
            'attributes',
            json.arrayOf(attributes)
        );
        string memory expected = json.objectOf(properties);

        test.setAttribute(
            layerId,
            Attribute('test', 'hello', DisplayType.String)
        );
        string memory actual = test.getLayerJson(layerId);
        assertEq(actual, expected);
    }

    function testInitialize_InvalidInitialization() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidInitialization.selector));
        test.initialize(address(0), '', 1, 1, '', '');
    }

    function testSetWidth() public {
        test.setWidth(69);
        assertEq(test.getWidth(), 69);
    }

    function testSetHeight() public {
        test.setHeight(69);
        assertEq(test.getHeight(), 69);
    }

    function testSetDefaultURI() public {
        test.setDefaultURI('hello');
        assertEq(test.getDefaultURI(), 'hello');
    }

    function testSetBaseLayerURI() public {
        test.setBaseLayerURI('hello');
        assertEq(test.getBaseLayerURI(), 'hello');
    }

    function tesetInitializeConstructor() public {
        test = new ImageLayerableImpl();
        assertEq(test.owner(), address(this));
        assertEq(test.getHeight(), 100);
        assertEq(test.getWidth(), 100);
        assertEq(test.getDefaultURI(), 'default');
    }

    function testInitialize_noCode() public {
        vm.prank(address(12345));

        vm.record();
        InitializeTester initializeTester = new InitializeTester(address(test));
        (, bytes32[] memory writes) = vm.accesses(address(initializeTester));
        uint256[] memory values = new uint256[](writes.length);
        for (uint256 i; i < writes.length; ++i) {
            bytes32 slot = writes[i];
            uint256 value = initializeTester.readSlot(uint256(slot));
            values[i] = value;
        }
        assertEq(values[0], uint160(address(5)));
        assertEq(
            values[1],
            0x64656661756c740000000000000000000000000000000000000000000000000e
        );
        assertEq(values[2], 100);
        assertEq(values[3], 100);
    }
}
