// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { IGovernor } from "../src/interfaces/IGovernor.sol";
import { IToken } from "../src/interfaces/IToken.sol";
import { ITimelock } from "../src/interfaces/ITimelock.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";

import { SecurityCouncil } from "../src/SecurityCouncil.sol";
import { Users } from "./utils/Types.sol";

/// @notice Base test contract with common logic needed by all tests.
contract Base_Test is Test {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IToken public token;
    IGovernor public governor;
    ITimelock public timelock;
    SecurityCouncil public securityCouncil;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        vm.createSelectFork({ blockNumber: 19_618_708, urlOrAlias: "mainnet" });

        // Create users for testing.
        users = Users({
            deployer: makeAddr("Deployer"),
            alice: makeAddr("Alice"),
            securityCouncilMultisig: makeAddr("SecurityCouncilMultisig"),
            attacker: makeAddr("Attacker")
        });

        // Governance contracts ENS
        token = IToken(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);
        governor = IGovernor(0x323A76393544d5ecca80cd6ef2A560C6a395b7E3);
        timelock = ITimelock(payable(0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7));

        // Deplpoy security council
        vm.prank(users.deployer);
        securityCouncil = new SecurityCouncil(
            users.securityCouncilMultisig, timelock, IRegistry(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e)
        );

        // Label the base test contracts.
        vm.label(address(governor), "governor");
        vm.label(address(timelock), "timelock");
        vm.label(address(token), "token");
        vm.label(address(securityCouncil), "securityCouncil");
    }
}
