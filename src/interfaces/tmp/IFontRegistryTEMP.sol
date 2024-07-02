// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title The FontRegistry interface
/// @dev Useful as a lightweight dependency import without drastically increasing runtime bytecode
/// @author 📯📯📯.eth

interface IFontRegistry {
    function getFont(string calldata fontName) external view returns (string memory);
    function getFontKey(string calldata fontName) external pure returns (bytes32);

    /// @dev Gated functions (restricted to the owner only)
    function addFontToRegistry(address fontAddress) external;
    function deleteFontFromRegistry(address fontAddress) external;
}