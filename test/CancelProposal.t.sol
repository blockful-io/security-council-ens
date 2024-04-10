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
    ITimelock public timelock;
    IWallet public daoWallet;
    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    address voter = address(0x1);

    function setUp() public {
        vm.createSelectFork({ blockNumber: 19_618_708, urlOrAlias: "mainnet" });

        token = IToken(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72);
        governor = IGovernor(0x323A76393544d5ecca80cd6ef2A560C6a395b7E3);
        timelock = ITimelock(0xd7A029Db2585553978190dB5E85eC724Aa4dF23f);
        daoWallet = IWallet(payable(0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7));

        vm.prank(0xd7A029Db2585553978190dB5E85eC724Aa4dF23f);
        token.delegate(voter);

        labelAddresses();
    }

    function test_BaseConfig() public {
        address tokenInGovernor = governor.token();
        assertEq(tokenInGovernor, address(token));

        bool governorIsProposerInWallet = daoWallet.hasRole(PROPOSER_ROLE, address(governor));
        assertTrue(governorIsProposerInWallet);

        uint256 votingPower = token.getVotes(voter);
        assertEq(votingPower, 55_004_056_347_480_195_848_226_739);
    }

    function test_AttackDAO() public {
        address[] memory targets = new address[](1);
        targets[0] = address(daoWallet);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(daoWallet.grantRole, (daoWallet.PROPOSER_ROLE(), voter));

            uint256 votingPower = token.getVotes(voter);
        assertEq(votingPower, 55_004_056_347_480_195_848_226_739);
        console.log(governor.proposalThreshold());
        vm.prank(voter);
        governor.propose(targets, values, calldatas, "");
    }


    /// @dev Labels the most relevant addresses.
    function labelAddresses() internal {
        vm.label({ account: voter, newLabel: "VOTER" });
        vm.label({ account: address(governor), newLabel: "governor" });
        vm.label({ account: address(timelock), newLabel: "timelock" });
        vm.label({ account: address(daoWallet), newLabel: "daoWallet" });
        vm.label({ account: address(token), newLabel: "token" });
    }
}
