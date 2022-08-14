// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';
import {Attribute} from 'bound-layerable/interface/Structs.sol';
import {DisplayType, LayerType} from 'bound-layerable/interface/Enums.sol';
import {PackedByteUtility} from 'bound-layerable/lib/PackedByteUtility.sol';
import {BitMapUtility} from 'bound-layerable/lib/BitMapUtility.sol';
import {StringTestUtility} from '../helpers/StringTestUtility.sol';
import {LibString} from 'solady/utils/LibString.sol';
import {InvalidInitialization} from 'bound-layerable/interface/Errors.sol';

contract LayerableImpl is ImageLayerable {
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

contract LayerableTest is Test {
    using BitMapUtility for uint256;
    using StringTestUtility for string;
    using LibString for uint256;
    using LibString for uint8;

    LayerableImpl test;

    function setUp() public {
        test = new LayerableImpl();
        test.setBaseLayerURI('layer/'); // test.setLayerTypeDistribution(LayerType.PORTRAIT, 0xFF << 248);
    }

    function testGetActiveLayerTraits(uint8[2] memory activeLayers) public {
        uint256[] memory activeLayersCopy = new uint256[](2);
        for (uint8 i = 0; i < activeLayers.length; i++) {
            activeLayersCopy[i] = activeLayers[i];
        }
        for (uint256 i = 0; i < activeLayers.length; i++) {
            test.setAttribute(
                activeLayers[i],
                Attribute(
                    activeLayers[i].toString(),
                    activeLayers[i].toString(),
                    DisplayType.String
                )
            );
        }

        string memory actual = test.getActiveLayerTraits(activeLayersCopy);

        emit log_string(actual);
        for (uint256 i = 0; i < activeLayers.length; i++) {
            assertTrue(
                actual.contains(
                    string.concat(
                        '{"trait_type":"Active ',
                        activeLayers[i].toString(),
                        '","value":"',
                        activeLayers[i].toString(),
                        '"}'
                    )
                )
            );
        }
    }

    function testBoundLayerTraits(uint8[2] memory boundLayers) public {
        uint256 bindings;
        for (uint256 i = 0; i < boundLayers.length; i++) {
            bindings |= 1 << boundLayers[i];

            test.setAttribute(
                boundLayers[i],
                Attribute(
                    boundLayers[i].toString(),
                    boundLayers[i].toString(),
                    DisplayType.String
                )
            );
        }

        string memory actual = test.getBoundLayerTraits(bindings);

        emit log_string(actual);
        for (uint256 i = 0; i < boundLayers.length; i++) {
            assertTrue(
                actual.contains(
                    string.concat(
                        '{"trait_type":"',
                        boundLayers[i].toString(),
                        '","value":"',
                        boundLayers[i].toString(),
                        '"}'
                    )
                )
            );
        }
    }

    function testInitialize_InvalidInitialization() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidInitialization.selector));
        test.initialize(address(0));
    }
}
