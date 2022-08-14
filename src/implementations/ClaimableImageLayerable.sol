// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoundLayerable} from 'bound-layerable/BoundLayerable.sol';
import {LayerVariation} from 'bound-layerable/interface/Structs.sol';
import {ImageLayerable} from 'bound-layerable/metadata/ImageLayerable.sol';

contract ClaimableImageLayerable is ImageLayerable {
    uint256 private constant BITMASK_BURNED = 1 << 224;

    constructor(address _owner) ImageLayerable(_owner, '', 100, 100) {}

    function claimOwnership() public {
        _transferOwnership(msg.sender);
    }

    function grantOwnership(address newOwner) public {
        _transferOwnership(newOwner);
    }
}
