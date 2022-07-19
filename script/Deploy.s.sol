// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {TestnetToken} from '../src/implementations/TestnetToken.sol';
import {Layerable} from '../src/metadata/Layerable.sol';
import {ImageLayerable} from '../src/metadata/ImageLayerable.sol';
import {Attribute} from '../src/interface/Structs.sol';
import {DisplayType} from '../src/interface/Enums.sol';
import {Strings} from 'openzeppelin-contracts/utils/Strings.sol';

contract Deploy is Script {
    using Strings for uint256;

    struct AttributeTuple {
        uint256 traitId;
        string name;
    }

    function getLayerTypeStr(uint256 layerId)
        public
        pure
        returns (string memory result)
    {
        uint256 layerType = (layerId - 1) / 32;
        if (layerType == 0) {
            result = 'Portrait';
        } else if (layerType == 1) {
            result = 'Background';
        } else if (layerType == 2) {
            result = 'Texture';
        } else if (layerType == 5 || layerType == 6) {
            result = 'Border';
        } else {
            result = 'Object';
        }
    }

    function run() public {
        // address coordinator;
        // uint256 chainId;
        // assembly {
        //     chainId := chainid()
        // }
        // coordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
        address deployer = 0x92B381515bd4851Faf3d33A161f7967FD87B1227;
        vm.startBroadcast(deployer);

        // emit log_named_uint('chainid', chainId);
        // if (chainId == 4) {
        // } else if (chainId == 137) {
        //     coordinator = 0xAE975071Be8F8eE67addBC1A82488F1C24858067;
        // } else if (chainId == 80001) {
        //     coordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
        // } else {
        //     coordinator = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
        // }
        // emit log_named_address('coordinator', coordinator);
        TestnetToken token = new TestnetToken();
        // token.setMetadataContract(layerable);
    }
}
