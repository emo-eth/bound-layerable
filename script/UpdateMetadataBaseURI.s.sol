// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Script} from 'forge-std/Script.sol';
import {TestnetToken} from '../src/implementations/TestnetToken.sol';
import {ImageLayerable} from '../src/metadata/ImageLayerable.sol';
import {Attribute} from '../src/interface/Structs.sol';
import {DisplayType} from '../src/interface/Enums.sol';
import {TransparentUpgradeableProxy} from 'openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {Solenv} from 'solenv/Solenv.sol';

contract Deploy is Script {
    struct AttributeTuple {
        uint256 traitId;
        string name;
    }

    function setUp() public virtual {
        Solenv.config();
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
        Solenv.config();

        address deployer = vm.envAddress('DEPLOYER');
        address metadataContract = vm.envAddress('METADATA_PROXY');
        string memory baseLayerURI = vm.envString('BASE_LAYER_URI');

        // use a separate admin account to deploy the proxy
        vm.startBroadcast(deployer);
        // deploy this to have a copy of implementation logic
        ImageLayerable metadata = ImageLayerable(metadataContract); //, deployer);

        metadata.setBaseLayerURI(baseLayerURI);
    }
}
