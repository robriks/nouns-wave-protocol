// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IPropLot} from "src/interfaces/IPropLot.sol";
import {PropLotTest} from "test/PropLot.t.sol";
import {PropLotHarness} from "test/harness/PropLotHarness.sol";

/// @notice Fuzz iteration params can be increased to larger types to match implementation
/// They are temporarily set to smaller types for speed only
contract IdeaTokenHubTest is PropLotTest {
    function test_finalizeAuction() public {
        setUp();
    }
}