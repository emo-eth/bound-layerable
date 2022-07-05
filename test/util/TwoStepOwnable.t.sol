// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Test} from 'forge-std/Test.sol';
import {TwoStepOwnable} from 'bound-layerable/util/TwoStepOwnable.sol';

contract TwoStepOwnableTest is TwoStepOwnable, Test {
    TwoStepOwnable ownable;

    function setUp() public {
        ownable = TwoStepOwnable(address(this));
        vm.prank(ownable.owner());
        ownable.transferOwnership(address(this));
        ownable.claimOwnership();
    }

    function testTransferOwnershipDoesNotImmediatelyTransferOwnership() public {
        ownable.transferOwnership(address(1));
        assertEq(ownable.owner(), address(this));
    }

    function testTransferOwnershipRejectsZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature('NewOwnerIsZeroAddress()'));
        ownable.transferOwnership(address(0));
    }

    function testClaimOwnership() public {
        ownable.transferOwnership(address(1));
        vm.prank(address(1));
        ownable.claimOwnership();
        assertEq(ownable.owner(), address(1));
    }

    function testTransferOwnershipIsStillOnlyOwner() public {
        ownable.transferOwnership(address(1));
        vm.prank(address(1));
        ownable.claimOwnership();
        // prank is over, back to regular address
        vm.expectRevert('Ownable: caller is not the owner');
        ownable.transferOwnership(address(5));
    }

    function testCancelTransferOwnership() public {
        ownable.transferOwnership(address(1));
        ownable.cancelOwnershipTransfer();
        vm.startPrank(address(1));
        vm.expectRevert(abi.encodeWithSignature('NotNextOwner()'));
        ownable.claimOwnership();
    }

    function testNotNextOwner() public {
        ownable.transferOwnership(address(1));
        vm.startPrank(address(5));
        vm.expectRevert(abi.encodeWithSignature('NotNextOwner()'));
        ownable.claimOwnership();
    }

    function testOnlyOwnerCanCancelTransferOwnership() public {
        ownable.transferOwnership(address(1));
        vm.prank(address(1));
        ownable.claimOwnership();
        // prank is over
        vm.expectRevert('Ownable: caller is not the owner');
        ownable.cancelOwnershipTransfer();
    }
}
