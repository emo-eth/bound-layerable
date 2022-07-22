// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {Attribute} from 'bound-layerable/interface/Structs.sol';
import {DisplayType} from 'bound-layerable/interface/Enums.sol';
import {StringTestUtility} from '../helpers/StringTestUtility.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';

contract ImageLayerableImpl is ImageLayerable {
    uint256 bindings;
    uint256[] activeLayers;
    bytes32 packedBatchRandomness;

    constructor() ImageLayerable('default', msg.sender) {}

    function setBindings(uint256 _bindings) public {
        bindings = _bindings;
    }

    function setActiveLayers(uint256[] memory _activeLayers) public {
        activeLayers = _activeLayers;
    }

    function setPackedBatchRandomness(bytes32 _packedBatchRandomness) public {
        packedBatchRandomness = _packedBatchRandomness;
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
    using Strings for uint256;

    ImageLayerableImpl test;

    function setUp() public {
        test = new ImageLayerableImpl();
        test.setBaseLayerURI('layer/');
    }

    function testGetTokenUri() public {
        // no seed means default metadata
        string
            memory expected = 'data:application/json;utf8,{"image":"default"}';
        string memory actual = test.tokenURI(0);
        assertEq(actual, expected);
        test.setPackedBatchRandomness(bytes32(uint256(1)));

        // once seeded, if not bound, regular nft metadata
        // test.setPackedBatchRandomness(bytes32(uint256(1)));
        expected = 'data:application/json;utf8,{"image":"layer/1","attributes":[{"trait_type":"Layer Type","value":"test"},{"trait_type":"test","value":"hello"}]}';

        test.setAttribute(1, Attribute('test', 'hello', DisplayType.String));
        test.setAttribute(2, Attribute('test2', 'hello2', DisplayType.Number));

        actual = test.tokenURI(1);
        assertEq(actual, expected);

        // once bound, show layers
        uint256 boundLayers = 3 << 1;
        test.setBindings(boundLayers);
        // test.bindLayers(0, 3 << 1);
        // no active layers
        expected = 'data:application/json;utf8,{"image":"<svg xmlns="http://www.w3.org/2000/svg"></svg>","attributes":[{"trait_type":"test","value":"hello"},{"trait_type":"test2","display_type":"number","value":"hello2"}]}';
        actual = test.tokenURI(1);
        assertEq(actual, expected);
        uint256[] memory activeLayers = new uint256[](2);
        // activeLayers[0] = (0x02 << 248) | (0x01 << 240);
        activeLayers[0] = 2;
        activeLayers[1] = 1;

        test.setActiveLayers(activeLayers);
        expected = 'data:application/json;utf8,{"image":"<svg xmlns="http://www.w3.org/2000/svg"><image href="layer/2"  height="100%" /><image href="layer/1"  height="100%" /></svg>","attributes":[{"trait_type":"test","value":"hello"},{"trait_type":"test2","display_type":"number","value":"hello2"},{"trait_type":"Active test2","display_type":"number","value":"hello2"},{"trait_type":"Active test","value":"hello"}]}';
        actual = test.tokenURI(1);
        assertEq(actual, expected);
    }

    function testGetTokenUri(uint256 layerId) public {
        // no seed means default metadata
        string
            memory expected = 'data:application/json;utf8,{"image":"default"}';
        string memory actual = test.tokenURI(layerId);
        assertEq(actual, expected);
        test.setPackedBatchRandomness(bytes32(uint256(1)));

        expected = string.concat(
            'data:application/json;utf8,{"image":"layer/',
            layerId.toString(),
            '","attributes":[{"trait_type":"Layer Type","value":"test"},{"trait_type":"test","value":"hello"}]}'
        );
        test.setAttribute(
            layerId,
            Attribute('test', 'hello', DisplayType.String)
        );
        actual = test.tokenURI(layerId);
        assertEq(actual, expected);
        test.setBindings(1);
        actual = test.tokenURI(layerId);
        assertEq(actual, expected);
    }
}
