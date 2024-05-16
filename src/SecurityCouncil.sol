// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ITimelock } from "./interfaces/ITimelock.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

import { ReverseClaimer } from "./ReverseClaimer.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SecurityCouncil
 * @dev A contract to cancel proposals in the timelock, controlled by a Security Council multisig.
 */
contract SecurityCouncil is ReverseClaimer, AccessControl {
    ITimelock public immutable timelock;
    uint256 public immutable expiration;

    bytes32 public constant VETO_ROLE = keccak256("VETO_ROLE");

    error ExpirationNotReached();

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

        // Set expiration to 2 years from deployment
        expiration = block.timestamp + (2 * 365 days);

        _grantRole(VETO_ROLE, securityCouncilMultisig);
    }

    /**
     * @dev Function to cancel a proposal in the timelock.
     * @param proposalId ID of the proposal to cancel.
     */
    function veto(bytes32 proposalId) external onlyRole(VETO_ROLE) {
        timelock.cancel(proposalId);
    }

    /**
     * @dev Function to renounce the veto role after expiration.
     */
    function renounceVetoRoleByExpiration() public {
        if (block.timestamp < expiration) {
            revert ExpirationNotReached();
        }

        timelock.renounceRole(timelock.PROPOSER_ROLE(), address(this));
    }
}
