// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Base_Test } from "../../Base.t.sol";

contract Security_Council_Integration_Concrete_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();

        // grants role to security council in timelock
        vm.prank(address(timelock));
        timelock.grantRole(PROPOSER_ROLE, address(securityCouncil));

        // security council multisig accepting ownership
        vm.prank(users.securityCouncilMultisig);
        securityCouncil.acceptOwnership();
    }
}
