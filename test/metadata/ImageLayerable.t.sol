// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {Attribute} from 'bound-layerable/interface/Structs.sol';
import {DisplayType} from 'bound-layerable/interface/Enums.sol';
import {StringTestUtility} from '../helpers/StringTestUtility.sol';
import {LibString} from 'solady/utils/LibString.sol';
import {InvalidInitialization} from 'bound-layerable/interface/Errors.sol';

contract ImageLayerableImpl is ImageLayerable {
    uint256 bindings;
    uint256[] activeLayers;
    bytes32 packedBatchRandomness;

    constructor() ImageLayerable(msg.sender, 'default', 100, 100) {}

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
                bindings,
                activeLayers,
                packedBatchRandomness
            );
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

    function testGetTokenURI() public {
        // no seed means default metadata
        string
            memory expected = 'data:application/json;base64,eyJpbWFnZSI6ImRlZmF1bHQifQ==';
        string memory actual = test.tokenURI(0);
        assertEq(actual, expected);
        test.setPackedBatchRandomness(bytes32(uint256(1)));

        // once seeded, if not bound, regular nft metadata
        // test.setPackedBatchRandomness(bytes32(uint256(1)));
        expected = 'data:application/json;base64,eyJpbWFnZSI6ImxheWVyLzEiLCJhdHRyaWJ1dGVzIjpbeyJ0cmFpdF90eXBlIjoiTGF5ZXIgVHlwZSIsInZhbHVlIjoidGVzdCJ9LHsidHJhaXRfdHlwZSI6InRlc3QiLCJ2YWx1ZSI6ImhlbGxvIn1dfQ==';
        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
        test.setAttribute(2, Attribute('test2', 'hello2', DisplayType.Number));

        actual = test.tokenURI(1);
        assertEq(actual, expected);

        // once bound, show layers
        uint256 boundLayers = 3 << 1;
        test.setBindings(boundLayers);
        // test.bindLayers(0, 3 << 1);
        // no active layers
        expected = 'data:application/json;base64,eyJpbWFnZSI6ImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjRiV3h1Y3owaWFIUjBjRG92TDNkM2R5NTNNeTV2Y21jdk1qQXdNQzl6ZG1jaUlHaGxhV2RvZEQwaU1UQXdJaUFnZDJsa2RHZzlJakV3TUNJZ1Bqd3ZjM1puUGc9PSIsImF0dHJpYnV0ZXMiOlt7InRyYWl0X3R5cGUiOiJ0ZXN0IiwidmFsdWUiOiJoZWxsbyJ9LHsidHJhaXRfdHlwZSI6InRlc3QyIiwiZGlzcGxheV90eXBlIjoibnVtYmVyIiwidmFsdWUiOiJoZWxsbzIifSx7InRyYWl0X3R5cGUiOiJMYXllciBDb3VudCIsImRpc3BsYXlfdHlwZSI6Im51bWJlciIsInZhbHVlIjoiMiJ9XX0=';
        actual = test.tokenURI(1);
        assertEq(actual, expected);
        uint256[] memory activeLayers = new uint256[](2);
        // activeLayers[0] = (0x02 << 248) | (0x01 << 240);
        activeLayers[0] = 2;
        activeLayers[1] = 1;

        test.setActiveLayers(activeLayers);
        expected = 'data:application/json;base64,eyJpbWFnZSI6ImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjRiV3h1Y3owaWFIUjBjRG92TDNkM2R5NTNNeTV2Y21jdk1qQXdNQzl6ZG1jaUlHaGxhV2RvZEQwaU1UQXdJaUFnZDJsa2RHZzlJakV3TUNJZ1BqeHBiV0ZuWlNCb2NtVm1QU0pzWVhsbGNpOHlJaUFnYUdWcFoyaDBQU0l4TURBbElpQWdkMmxrZEdnOUlqRXdNQ1VpSUM4K1BHbHRZV2RsSUdoeVpXWTlJbXhoZVdWeUx6RWlJQ0JvWldsbmFIUTlJakV3TUNVaUlDQjNhV1IwYUQwaU1UQXdKU0lnTHo0OEwzTjJaejQ9IiwiYXR0cmlidXRlcyI6W3sidHJhaXRfdHlwZSI6InRlc3QiLCJ2YWx1ZSI6ImhlbGxvIn0seyJ0cmFpdF90eXBlIjoidGVzdDIiLCJkaXNwbGF5X3R5cGUiOiJudW1iZXIiLCJ2YWx1ZSI6ImhlbGxvMiJ9LHsidHJhaXRfdHlwZSI6IkxheWVyIENvdW50IiwiZGlzcGxheV90eXBlIjoibnVtYmVyIiwidmFsdWUiOiIyIn0seyJ0cmFpdF90eXBlIjoiQWN0aXZlIHRlc3QyIiwiZGlzcGxheV90eXBlIjoibnVtYmVyIiwidmFsdWUiOiJoZWxsbzIifSx7InRyYWl0X3R5cGUiOiJBY3RpdmUgdGVzdCIsInZhbHVlIjoiaGVsbG8ifV19';
        actual = test.tokenURI(1);
        assertEq(actual, expected);
    }

    function testGetTokenJson() public {
        // no seed means default metadata
        string memory expected = '{"image":"default"}';
        string memory actual = test.tokenJson(0);
        assertEq(actual, expected);
        test.setPackedBatchRandomness(bytes32(uint256(1)));

        // once seeded, if not bound, regular nft metadata
        // test.setPackedBatchRandomness(bytes32(uint256(1)));
        expected = '{"image":"layer/1","attributes":[{"trait_type":"Layer Type","value":"test"},{"trait_type":"test","value":"hello"}]}';

        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
        test.setAttribute(2, Attribute('test2', 'hello2', DisplayType.Number));

        actual = test.tokenJson(1);
        assertEq(actual, expected);

        // once bound, show layers
        uint256 boundLayers = 3 << 1;
        test.setBindings(boundLayers);
        // test.bindLayers(0, 3 << 1);
        // no active layers
        expected = '{"image":"data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMTAwIiAgd2lkdGg9IjEwMCIgPjwvc3ZnPg==","attributes":[{"trait_type":"test","value":"hello"},{"trait_type":"test2","display_type":"number","value":"hello2"},{"trait_type":"Layer Count","display_type":"number","value":"2"}]}';
        actual = test.tokenJson(1);
        assertEq(actual, expected);
        uint256[] memory activeLayers = new uint256[](2);
        // activeLayers[0] = (0x02 << 248) | (0x01 << 240);
        activeLayers[0] = 2;
        activeLayers[1] = 1;

        test.setActiveLayers(activeLayers);
        expected = '{"image":"data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGhlaWdodD0iMTAwIiAgd2lkdGg9IjEwMCIgPjxpbWFnZSBocmVmPSJsYXllci8yIiAgaGVpZ2h0PSIxMDAlIiAgd2lkdGg9IjEwMCUiIC8+PGltYWdlIGhyZWY9ImxheWVyLzEiICBoZWlnaHQ9IjEwMCUiICB3aWR0aD0iMTAwJSIgLz48L3N2Zz4=","attributes":[{"trait_type":"test","value":"hello"},{"trait_type":"test2","display_type":"number","value":"hello2"},{"trait_type":"Layer Count","display_type":"number","value":"2"},{"trait_type":"Active test2","display_type":"number","value":"hello2"},{"trait_type":"Active test","value":"hello"}]}';
        actual = test.tokenJson(1);
        assertEq(actual, expected);
    }

    function testGetTokenJson(uint256 layerId) public {
        // no seed means default metadata
        string memory expected = '{"image":"default"}';
        string memory actual = test.tokenJson(layerId);
        assertEq(actual, expected);
        test.setPackedBatchRandomness(bytes32(uint256(1)));

        expected = string.concat(
            '{"image":"layer/',
            layerId.toString(),
            '","attributes":[{"trait_type":"Layer Type","value":"test"},{"trait_type":"test","value":"hello"}]}'
        );
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
        string memory expected = string.concat(
            '{"image":"layer/',
            layerId.toString(),
            '","attributes":[{"trait_type":"Layer Type","value":"test"},{"trait_type":"test","value":"hello"}]}'
        );
        test.setAttribute(
            layerId,
            Attribute('test', 'hello', DisplayType.String)
        );
        string memory actual = test.getLayerJson(layerId);
        assertEq(actual, expected);
    }

    function testInitialize_InvalidInitialization() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidInitialization.selector));
        test.initialize(address(0), '', 1, 1);
    }
}
