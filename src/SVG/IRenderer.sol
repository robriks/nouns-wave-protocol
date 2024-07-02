// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @dev Interface for the Wave Renderer contract which dynamically renders token URI metadata
interface IRenderer {
    
    struct BadgeConfig {
        string hexString;
        uint256 partId;
    }

    function generateSVG(uint256 tokenId) external view returns (string memory svg);
}