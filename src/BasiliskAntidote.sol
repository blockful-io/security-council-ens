// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ITimelock } from "./interfaces/ITimelock.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

import { ReverseClaimer } from "./ReverseClaimer.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract BasiliskAntidote is ReverseClaimer, AccessControl {
    ITimelock public immutable timelock;
    bytes32 public constant VETO_ROLE = keccak256("VETO_ROLE");

    constructor(ITimelock _daoWallet, IRegistry ensRegistry) ReverseClaimer(ensRegistry, msg.sender) {
        timelock = _daoWallet;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Only admin
    function veto(bytes32 proposalId) external onlyRole(VETO_ROLE) {
        // call cancel() on DAO wallet
        timelock.cancel(proposalId);
    }
}
