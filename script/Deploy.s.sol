// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from 'forge-std/Test.sol';
import {Script} from 'forge-std/Script.sol';
import {TestnetToken} from '../src/implementations/TestnetToken.sol';
import {Layerable} from '../src/metadata/Layerable.sol';
import {ImageLayerable} from '../src/metadata/ImageLayerable.sol';
import {Attribute} from '../src/interface/Structs.sol';
import {DisplayType} from '../src/interface/Enums.sol';
import {Strings} from 'openzeppelin-contracts/contracts/utils/Strings.sol';
import {Solenv} from 'solenv/Solenv.sol';

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

    function setUp() public virtual {
        Solenv.config();
    }

    function run() public {
        address deployer = vm.envAddress('DEPLOYER');
        vm.startBroadcast(deployer);
        // if (chainId == 4) {coordinator 0x6168499c0cFfCaCD319c818142124B7A15E857ab
        // } else if (chainId == 137) {
        //     coordinator = 0xAE975071Be8F8eE67addBC1A82488F1C24858067;
        // } else if (chainId == 80001) {
        //     coordinator = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
        // } else {
        //     coordinator = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
        // }
        // emit log_named_address('coordinator', coordinator);
        TestnetToken token = new TestnetToken();
    }
}
