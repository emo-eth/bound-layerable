// SPDX-License-Identifier: UNLICENSED
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
        address deployer = vm.envAddress('DEPLOYER');
        address admin = vm.envAddress('ADMIN');
        address tokenAddress = vm.envAddress('TOKEN');
        string memory defaultURI = vm.envString('DEFAULT_URI');
        string memory baseLayerURI = vm.envString('BASE_LAYER_URI');

        // use a separate admin account to deploy the proxy
        vm.startBroadcast(admin);
        // deploy this to have a copy of implementation logic
        ImageLayerable logic = new ImageLayerable(
            deployer,
            defaultURI,
            1000,
            1250,
            'https://slimeshop.slimesunday.com/',
            'Test Description'
        );

        // deploy proxy using the logic contract, setting "deployer" addr as owner
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(logic),
            admin,
            abi.encodeWithSignature(
                'initialize(address,string,uint256,uint256,string,string)',
                deployer,
                'default',
                1000,
                1250,
                'https://slimeshop.slimesunday.com/',
                'Test Description'
            )
        );
        vm.stopBroadcast();

        vm.startBroadcast(deployer);
        // configure layerable contract metadata
        ImageLayerable layerable = ImageLayerable(address(proxy));
        layerable.setBaseLayerURI(baseLayerURI);

        // uint256[] memory layerIds = []
        // Attribute[] memory attributes = []
        // layerable.setAttributes(layerIds, attributes);

        // set metadata contract on token
        // TestnetToken token = TestnetToken(tokenAddress);
        // token.setMetadataContract(layerable);
    }
}
