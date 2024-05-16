// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Security_Council_Unit_Concrete_Test } from "./securityCouncil.t.sol";

contract Veto_Unit_Concrete_Test is Security_Council_Unit_Concrete_Test {
    bytes32 proposalIdInTimelock;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    bytes32 descriptionHash;

    function setUp() public virtual override {
        Security_Council_Unit_Concrete_Test.setUp();

        // Delegate from top token holder (binance, with 4m $ENS in this case)
        vm.prank(0x5a52E96BAcdaBb82fd05763E25335261B270Efcb);
        token.delegate(users.attacker);

        uint256 votingPower = token.getVotes(users.attacker);
        assertEq(votingPower, 4_126_912_192_000_000_000_000_000);

        // Need to advance 1 block for delegation to be valid on governor
        vm.roll(block.number + 1);

        // Creating a malicious proposal to takeover the timelock
        targets = new address[](3);
        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = users.attacker;
        values = new uint256[](3);
        values[0] = 0;
        values[1] = 0;
        values[2] = 5_370_845_482_402_118_767_544;
        calldatas = new bytes[](3);
        calldatas[0] = abi.encodeCall(timelock.grantRole, (timelock.PROPOSER_ROLE(), users.attacker));
        calldatas[1] = abi.encodeCall(timelock.revokeRole, (timelock.PROPOSER_ROLE(), address(governor)));
        calldatas[2] = bytes("");

        string memory description = "";
        descriptionHash = keccak256(bytes(description));

        // Submit malicious proposal
        vm.prank(users.attacker);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertEq(governor.state(proposalId), 0);

        // Proposal is ready to vote after 2 block because of the revert ERC20Votes: block not yet mined
        vm.roll(block.number + governor.votingDelay() + 1);
        assertEq(governor.state(proposalId), 1);

        // Vote for the proposal
        vm.prank(users.attacker);
        governor.castVote(proposalId, 1);

        // Let the voting end
        vm.roll(block.number + governor.votingPeriod());
        assertEq(governor.state(proposalId), 4);

        // Proposal is queued as an operation to be executed by the timelock
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(governor.state(proposalId), 5);

        // Calculate proposalId in timelock
        proposalIdInTimelock = timelock.hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
        assertTrue(timelock.isOperationPending(proposalIdInTimelock));

        // Check that operation exists
        assertTrue(timelock.isOperation(proposalIdInTimelock));
    }

    function test_Veto_Security_Coucil_Vetoing() public {
        // Security Council vetoing. Canceling the operation on timelock
        vm.prank(users.securityCouncilMultisig);
        securityCouncil.veto(proposalIdInTimelock);

        // Check that operation doesn't exists anymore
        assertFalse(timelock.isOperation(proposalIdInTimelock));

        // In the usual flow of the proposal this would return true
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        assertFalse(timelock.isOperationReady(proposalIdInTimelock));

        // Try to execute operation
        vm.expectRevert("TimelockController: operation is not ready");
        governor.execute(targets, values, calldatas, descriptionHash);
        assertFalse(timelock.isOperationDone(proposalIdInTimelock));

        // Check that the malicious proposal didn't had any effect.
        assertFalse(timelock.hasRole(PROPOSER_ROLE, users.attacker));
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(governor)));
    }

    function test_Veto_Random_User_Trying_Veto() public {
        // Expect to revert because isn't the security council multisig calling the veto
        vm.expectRevert();
        vm.prank(users.alice);
        securityCouncil.veto(proposalIdInTimelock);

        // Check that operation still exists
        assertTrue(timelock.isOperation(proposalIdInTimelock));
    }
}
