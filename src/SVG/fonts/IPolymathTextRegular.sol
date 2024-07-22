// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IFont} from "src/SVG/fonts/IFont.sol";

/// @title PolymathTextRegular Font as used by the Wave Protocol UI
/// @author 📯📯📯.eth
/// @dev Forward-compatible with the FontRegistry standard designed by 0xBeans
interface IPolymathTextRegular is IFont {
    /// @dev PolymathTextRegular occupies 12kb so there is only one partition (SSTORE2 pointer)
    function FONT_PARTITION() external returns (uint256);
    /// @dev The SSTORE2 pointer(s) for this font
    function files(uint256 partition) external returns (address);
    /// @dev Returns the 32 byte key used to record this interface's child in FontRegistry storage
    function fontRegistryKey() external returns (bytes32);
}
