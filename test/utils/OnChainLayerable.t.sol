// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {OnChainLayerable} from "../../src/utils/OnChainLayerable.sol";
import {Attribute} from "../../src/utils/Structs.sol";
import {DisplayType, LayerType} from "../../src/utils/Enums.sol";

contract OnChainLayerableImpl is OnChainLayerable {
    constructor() OnChainLayerable("default") {}

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        returns (string memory)
    {
        return getTokenURI(_tokenId);
    }
}

contract OnChainLayerableTest is Test {
    OnChainLayerableImpl test;

    function setUp() public {
        test = new OnChainLayerableImpl();
        test.setBaseLayerURI("layer/");
        test.setLayerTypeDistribution(LayerType.PORTRAIT, 0xFF << 248);
    }

    function testGetTokenUri() public {
        // no seed means default metadata
        string memory expected = "default";
        string memory actual = test.tokenURI(0);
        assertEq(abi.encode(actual), abi.encode(expected));

        // once seeded, if not bound, regular nft metadata
        test.setTraitGenerationSeed(bytes32(uint256(1)));
        expected = '{"image":"layer/1.png","attributes":"[{"trait_type":"test","value":"hello"}]"}';
        test.setAttribute(1, Attribute("test", "hello", DisplayType.String));
        test.setAttribute(2, Attribute("test2", "hello2", DisplayType.Number));

        actual = test.tokenURI(0);
        assertEq(abi.encode(actual), abi.encode(expected));

        // once bound, show layers
        test.bindLayers(0, 3 << 1);
        // no active layers
        expected = '{"image":"<svg xmlns="http://www.w3.org/2000/svg"></svg>","attributes":"[{"trait_type":"test","value":"hello"},{"trait_type":"test2","display_type":"number","value":"hello2"}]"}';
        actual = test.tokenURI(0);
        assertEq(abi.encode(actual), abi.encode(expected));
        uint256[] memory activeLayers = new uint256[](1);
        activeLayers[0] = (0x02 << 248) | (0x01 << 240);
        test.setActiveLayers(0, activeLayers);
        expected = '{"image":"<svg xmlns="http://www.w3.org/2000/svg"><image href="layer/2.png"  height="100%" /><image href="layer/1.png"  height="100%" /></svg>","attributes":"[{"trait_type":"test","value":"hello"},{"trait_type":"test2","display_type":"number","value":"hello2"}]"}';
        actual = test.tokenURI(0);
        assertEq(abi.encode(actual), abi.encode(expected));
    }
}
