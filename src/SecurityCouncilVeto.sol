// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ITimelock } from "./interfaces/ITimelock.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

import { ReverseClaimer } from "./ReverseClaimer.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract SecurityCouncilVeto is ReverseClaimer, AccessControl {
    ITimelock public immutable timelock;
    uint256 public immutable expiration;

    bytes32 public constant VETO_ROLE = keccak256("VETO_ROLE");

    error NotExpired();

    constructor(
        address securityCouncilMultisig,
        ITimelock _timelock,
        IRegistry ensRegistry
    )
        ReverseClaimer(ensRegistry, msg.sender)
    {
        timelock = _timelock;

        // 2 years of expiration
        expiration = block.timestamp + (2 * 365 days);

        _grantRole(VETO_ROLE, securityCouncilMultisig);
    }

    function veto(bytes32 proposalId) external onlyRole(VETO_ROLE) {
        timelock.cancel(proposalId);
    }

    function renounceVetoRoleByExpiration() public {
        if (expiration > block.timestamp) {
            revert NotExpired();
        }

        timelock.renounceRole(timelock.PROPOSER_ROLE(), address(this));
    }
}
