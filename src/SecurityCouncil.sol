// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ITimelock } from "./interfaces/ITimelock.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

import { ReverseClaimer } from "./ReverseClaimer.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title SecurityCouncil
 * @dev A contract to cancel proposals in the ENS timelock, controlled by the Security Council multisig.
 * @author Alexandro Netto - <alex@blockful.io>
 */
contract SecurityCouncil is ReverseClaimer, Ownable2Step {
    ITimelock public immutable timelock;
    uint256 public immutable expiration;

    error ExpirationNotReached();
    error ExpirationReached();

    /**
     * @dev Constructor to initialize the contract with the Security Council multisig and timelock.
     * @param securityCouncilMultisig Address of the Security Council multisig.
     * @param _timelock Address of the timelock contract.
     * @param ensRegistry Address of the ENS registry.
     */
    constructor(
        address securityCouncilMultisig,
        ITimelock _timelock,
        IRegistry ensRegistry
    )
        ReverseClaimer(ensRegistry, msg.sender)
    {
        timelock = _timelock;

        // Set expiration to 2 years from deployment + voting period
        expiration = block.timestamp + (2 * 365 days) + 7 days;

        // security council multisig needs to call acceptOwnership()
        transferOwnership(securityCouncilMultisig);
    }

    /**
     * @dev Function to cancel a proposal in the timelock.
     * @param proposalId ID of the proposal to cancel.
     */
    function veto(bytes32 proposalId) external onlyOwner {
        if (block.timestamp >= expiration) {
            revert ExpirationReached();
        }

        timelock.cancel(proposalId);
    }

    /**
     * @dev Function to renounce the veto role after expiration.
     */
    function renounceTimelockRoleByExpiration() external {
        if (block.timestamp < expiration) {
            revert ExpirationNotReached();
        }

        timelock.renounceRole(timelock.PROPOSER_ROLE(), address(this));
    }
}
