// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { IGovernor } from "../src/interfaces/IGovernor.sol";
import { IToken } from "../src/interfaces/IToken.sol";
import { ITimelock } from "../src/interfaces/ITimelock.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";

import { SecurityCouncilVeto } from "../src/SecurityCouncilVeto.sol";

contract SecurityCouncilVeto_Test is Test {
    IToken public token;
    IGovernor public governor;
    ITimelock public timelock;
    SecurityCouncilVeto public securityCouncilVeto;
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    address voter = address(0x1);
    address attacker = address(0x2);

    function setUp() public {
        vm.createSelectFork({ blockNumber: 19_618_708, urlOrAlias: "mainnet" });

        token = IToken(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);
        governor = IGovernor(0x323A76393544d5ecca80cd6ef2A560C6a395b7E3);
        timelock = ITimelock(payable(0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7));
        securityCouncilVeto = new SecurityCouncilVeto(timelock, IRegistry(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e));

        labelAddresses();
    }

    function test_BaseConfigChecks() public {
        address tokenInGovernor = governor.token();
        assertEq(tokenInGovernor, address(token));

        bool governorIsProposer = timelock.hasRole(PROPOSER_ROLE, address(governor));
        assertTrue(governorIsProposer);
    }

    function test_DefenseDAO() public {
        // Submit security council proposal

        // Delegate from top token holder (binance, with 4m $ENS in this case)
        vm.prank(0x5a52E96BAcdaBb82fd05763E25335261B270Efcb);
        token.delegate(voter);

        uint256 votingPower = token.getVotes(voter);
        assertEq(votingPower, 4_126_912_192_000_000_000_000_000);

        // Need to advance 1 block for delegation to be valid on governor
        vm.roll(block.number + 1);

        // Creating a proposal that gives a proposer role to
        address[] memory targets = new address[](1);
        targets[0] = address(timelock);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(timelock.grantRole, (timelock.PROPOSER_ROLE(), address(securityCouncilVeto)));

        string memory description = "";
        bytes32 descriptionHash = keccak256(bytes(description));

        // Governor //
        vm.prank(voter);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertEq(governor.state(proposalId), 0);

        // Proposal is ready to vote after 2 block because of the revert ERC20Votes: block not yet mined
        vm.roll(block.number + governor.votingDelay() + 1);
        assertEq(governor.state(proposalId), 1);

        // Vote for the proposal
        vm.prank(voter);
        governor.castVote(proposalId, 1);

        // Let the voting end
        vm.roll(block.number + governor.votingPeriod());
        assertEq(governor.state(proposalId), 4);

        // Queue the proposal to be executed
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(governor.state(proposalId), 5);

        // Calculate proposalId in timelock
        bytes32 proposalIdInTimelock = timelock.hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
        assertTrue(timelock.isOperationPending(proposalIdInTimelock));

        // Wait the operation in the DAO wallet timelock to be Ready
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        assertTrue(timelock.isOperationReady(proposalIdInTimelock));

        // Execute proposal
        governor.execute(targets, values, calldatas, descriptionHash);
        assertTrue(timelock.isOperationDone(proposalIdInTimelock));

        // Check result
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(securityCouncilVeto)));

        // Start attack
        // Delegate from top token holder (binance, with 4m $ENS in this case)
        vm.prank(0x5a52E96BAcdaBb82fd05763E25335261B270Efcb);
        token.delegate(attacker);

        uint256 votingPower2 = token.getVotes(attacker);
        assertEq(votingPower2, 4_126_912_192_000_000_000_000_000);

        // Need to advance 1 block for delegation to be valid on governor
        vm.roll(block.number + 1);

        // Creating a proposal that gives a proposer role to
        address[] memory targets2 = new address[](3);
        targets2[0] = address(timelock);
        targets2[1] = address(timelock);
        targets2[2] = attacker;
        uint256[] memory values2 = new uint256[](3);
        values2[0] = 0;
        values2[1] = 0;
        values2[2] = 5_370_845_482_402_118_767_544;
        bytes[] memory calldatas2 = new bytes[](3);
        calldatas2[0] = abi.encodeCall(timelock.grantRole, (timelock.PROPOSER_ROLE(), attacker));
        calldatas2[1] = abi.encodeCall(timelock.revokeRole, (timelock.PROPOSER_ROLE(), address(governor)));
        calldatas2[2] = bytes("");

        string memory description2 = "";
        bytes32 descriptionHash2 = keccak256(bytes(description2));

        // Governor //
        // Submit malicious proposal
        vm.prank(attacker);
        uint256 proposalId2 = governor.propose(targets2, values2, calldatas2, description2);
        assertEq(governor.state(proposalId2), 0);

        // Proposal is ready to vote after 2 block because of the revert ERC20Votes: block not yet mined
        vm.roll(block.number + governor.votingDelay() + 1);
        assertEq(governor.state(proposalId2), 1);

        // Vote for the proposal
        vm.prank(attacker);
        governor.castVote(proposalId2, 1);

        // Let the voting end
        vm.roll(block.number + governor.votingPeriod());
        assertEq(governor.state(proposalId2), 4);

        // Queue the proposal to be executed
        governor.queue(targets2, values2, calldatas2, descriptionHash2);
        assertEq(governor.state(proposalId2), 5);

        // Calculate proposalId in timelock
        bytes32 proposalIdInTimelock2 = timelock.hashOperationBatch(targets2, values2, calldatas2, 0, descriptionHash2);
        assertTrue(timelock.isOperationPending(proposalIdInTimelock2));

        securityCouncilVeto.veto(proposalIdInTimelock2);

        // Wait the operation in the DAO wallet timelock to be Ready
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        assertFalse(timelock.isOperationReady(proposalIdInTimelock2));

        // Execute proposal
        vm.expectRevert("TimelockController: operation is not ready");
        governor.execute(targets2, values2, calldatas2, descriptionHash2);
        assertFalse(timelock.isOperationDone(proposalIdInTimelock2));

        // Check result
        assertFalse(timelock.hasRole(PROPOSER_ROLE, attacker));
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(governor)));
    }

    /// @dev Labels the most relevant addresses.
    function labelAddresses() internal {
        vm.label({ account: voter, newLabel: "VOTER" });
        vm.label({ account: address(governor), newLabel: "governor" });
        vm.label({ account: address(timelock), newLabel: "timelock" });
        vm.label({ account: address(securityCouncilVeto), newLabel: "securityCouncilVeto" });
        vm.label({ account: address(token), newLabel: "token" });
    }
}
