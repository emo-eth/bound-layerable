// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Ownable} from 'openzeppelin-contracts/access/Ownable.sol';

/**
@notice A two-step extension of Ownable, where the new owner must claim ownership of the contract after owner initiates transfer
Owner can cancel the transfer at any point before the new owner claims ownership.
Helpful in guarding against transferring ownership to an address that is unable to act as the Owner.
*/
abstract contract TwoStepOwnable is Ownable {
    address internal _potentialOwner;

    error NewOwnerIsZeroAddress();
    error NotNextOwner();

    ///@notice Initiate ownership transfer to newPotentialOwner. Note: new owner will have to manually claimOwnership
    ///@param newPotentialOwner address of potential new owner
    function transferOwnership(address newPotentialOwner)
        public
        virtual
        override
        onlyOwner
    {
        if (newPotentialOwner == address(0)) {
            revert NewOwnerIsZeroAddress();
        }
        _potentialOwner = newPotentialOwner;
    }

    ///@notice Claim ownership of smart contract, after the current owner has initiated the process with transferOwnership
    function claimOwnership() public virtual {
        address potentialOwner = _potentialOwner;
        if (msg.sender != potentialOwner) {
            revert NotNextOwner();
        }
        _transferOwnership(potentialOwner);
        delete _potentialOwner;
    }

    ///@notice cancel ownership transfer
    function cancelOwnershipTransfer() public virtual onlyOwner {
        delete _potentialOwner;
    }
}
