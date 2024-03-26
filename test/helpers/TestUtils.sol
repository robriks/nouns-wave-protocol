// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC1155Holder} from "./MockERC1155Holder.sol";

/// @dev Test utility contract providing functionality for common testing tasks
/// such as creating traditional EOA and smart wallet addresses
abstract contract TestUtils is Test {
    /*
      Internals
    */

    /// @notice Returns an *unsafe* address createded with a *known private key*; for testing use _only_
    function _createNounderEOA(uint256 unsafeSeed) internal pure returns (address _newNounderEOA) {
        // increment `unsafeSeed` as private keys cannot be 0 and this intricacy should be abstracted away
        _newNounderEOA = vm.addr(unsafeSeed + 1);
    }

    /// @notice Deploys and returns a minimal smart account complying with `onERC1155Received`
    function _createNounderSmartAccount(uint256 salt) internal returns (address _newNounderSmartAccount) {
        _newNounderSmartAccount = address(new MockERC1155Holder{salt: bytes32(salt)}());
    }
}
