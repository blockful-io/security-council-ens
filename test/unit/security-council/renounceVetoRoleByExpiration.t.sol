// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { SecurityCouncil } from "../../../src/SecurityCouncil.sol";

import { Security_Council_Unit_Concrete_Test } from "./securityCouncil.t.sol";

contract RenounceVetoRoleByExpiration_Unit_Concrete_Test is Security_Council_Unit_Concrete_Test {
    function test_RenounceVetoRoleByExpiration_TooEarly() public {
        // Advance timestamp near to expiration
        vm.warp(securityCouncil.expiration() - 1);

        // Expect to revert because still no expired
        vm.expectRevert(SecurityCouncil.ExpirationNotReached.selector);
        vm.prank(users.alice);
        securityCouncil.renounceVetoRoleByExpiration();

        // Checks that the security council has role on timelock
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)));
    }

    function test_RenounceVetoRoleByExpiration_Success() public {
        // Advance timestamp to expiration
        vm.warp(securityCouncil.expiration());

        // Any address can renounce, once the expiration hits.
        vm.prank(users.alice);
        securityCouncil.renounceVetoRoleByExpiration();

        // Checks that the security council has no role on timelock
        assertFalse(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)));
    }
}
