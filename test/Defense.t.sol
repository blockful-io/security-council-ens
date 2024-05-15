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
    address deployer = address(0x3);
    address securityCouncilMultisig = address(0x4);

    function setUp() public {
        vm.createSelectFork({ blockNumber: 19_618_708, urlOrAlias: "mainnet" });

        token = IToken(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);
        governor = IGovernor(0x323A76393544d5ecca80cd6ef2A560C6a395b7E3);
        timelock = ITimelock(payable(0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7));

        vm.prank(deployer);
        securityCouncilVeto = new SecurityCouncilVeto(
            securityCouncilMultisig, timelock, IRegistry(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e)
        );

        labelAddresses();
    }

    function test_BaseConfigChecks() public {
        address tokenInGovernor = governor.token();
        assertEq(tokenInGovernor, address(token));

        bool governorIsProposer = timelock.hasRole(PROPOSER_ROLE, address(governor));
        assertTrue(governorIsProposer);
    }

    function test_Vetoing_Malicious_Proposal() public {
        // Give security council contract the role
        vm.startPrank(address(timelock));
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(securityCouncilVeto));
        vm.stopPrank();

        // Check result
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(securityCouncilVeto)));

        // Start attack
        // Delegate from top token holder (binance, with 4m $ENS in this case)
        vm.prank(0x5a52E96BAcdaBb82fd05763E25335261B270Efcb);
        token.delegate(attacker);

        uint256 votingPower = token.getVotes(attacker);
        assertEq(votingPower, 4_126_912_192_000_000_000_000_000);

        // Need to advance 1 block for delegation to be valid on governor
        vm.roll(block.number + 1);

        // Creating a malicious proposal to takeover the timelock
        address[] memory targets = new address[](3);
        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = attacker;
        uint256[] memory values = new uint256[](3);
        values[0] = 0;
        values[1] = 0;
        values[2] = 5_370_845_482_402_118_767_544;
        bytes[] memory calldatas = new bytes[](3);
        calldatas[0] = abi.encodeCall(timelock.grantRole, (timelock.PROPOSER_ROLE(), attacker));
        calldatas[1] = abi.encodeCall(timelock.revokeRole, (timelock.PROPOSER_ROLE(), address(governor)));
        calldatas[2] = bytes("");

        string memory description = "";
        bytes32 descriptionHash = keccak256(bytes(description));

        // Governor //
        // Submit malicious proposal
        vm.prank(attacker);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        assertEq(governor.state(proposalId), 0);

        // Proposal is ready to vote after 2 block because of the revert ERC20Votes: block not yet mined
        vm.roll(block.number + governor.votingDelay() + 1);
        assertEq(governor.state(proposalId), 1);

        // Vote for the proposal
        vm.prank(attacker);
        governor.castVote(proposalId, 1);

        // Let the voting end
        vm.roll(block.number + governor.votingPeriod());
        assertEq(governor.state(proposalId), 4);

        // Proposal is queued as an operation to be executed by the timelock
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(governor.state(proposalId), 5);

        // Calculate proposalId in timelock
        bytes32 proposalIdInTimelock = timelock.hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
        assertTrue(timelock.isOperationPending(proposalIdInTimelock));

        // Check that operation exists
        assertTrue(timelock.isOperation(proposalIdInTimelock));

        // Expect to revert because isn't the security council multisig calling the veto
        vm.expectRevert();
        vm.prank(deployer);
        securityCouncilVeto.veto(proposalIdInTimelock);

        // Security Council vetoing. Canceling the operation on timelock
        vm.prank(securityCouncilMultisig);
        securityCouncilVeto.veto(proposalIdInTimelock);

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
        assertFalse(timelock.hasRole(PROPOSER_ROLE, attacker));
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(governor)));
    }

    function test_Role_Expiration() public {
        vm.prank(address(timelock));
        timelock.grantRole(PROPOSER_ROLE, address(securityCouncilVeto));

        // Check result
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(securityCouncilVeto)));

        // Advance timestamp near to expiration
        vm.warp(securityCouncilVeto.expiration() - 1);

        // Expect to revert because still no expired
        vm.expectRevert(SecurityCouncilVeto.NotExpired.selector);
        securityCouncilVeto.renounceVetoRoleByExpiration();

        // Advance timestamp to expiration
        vm.warp(securityCouncilVeto.expiration());

        // Any address can renounce, once the expiration hits.
        securityCouncilVeto.renounceVetoRoleByExpiration();

        // Checks that the security council has no role on timelock
        assertFalse(timelock.hasRole(PROPOSER_ROLE, address(securityCouncilVeto)));
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
