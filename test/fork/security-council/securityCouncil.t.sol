// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Base_Test } from "../../Base.t.sol";
import { SecurityCouncil } from "../../../src/SecurityCouncil.sol";

contract Security_Council_Fork_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        users.securityCouncilMultisig = address(0xaA5cD05f6B62C3af58AE9c4F3F7A2aCC2Cdc2Cc7);
        securityCouncil = SecurityCouncil(0xB8fA0cE3f91F41C5292D07475b445c35ddF63eE0);
    }
}
