// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IWallet } from "./interfaces/IWallet.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

import { ReverseClaimer } from "./ReverseClaimer.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract BasiliskAntidote is ReverseClaimer, AccessControl {
    IWallet immutable public daoWallet;
    bytes32 constant public VETO_ROLE = keccak256("VETO_ROLE");

    constructor(IWallet _daoWallet, IRegistry ensRegistry) ReverseClaimer(ensRegistry, msg.sender) {
        daoWallet = _daoWallet;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Only admin
    function veto(bytes32 proposalId) external onlyRole(VETO_ROLE) {
        // call cancel() on DAO wallet
        daoWallet.cancel(proposalId);
    }
}
