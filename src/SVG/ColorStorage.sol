// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract ColorStorage {
    using Strings for uint256;

    // [light, medium, dark, wave1, wave2, wave3]
    string[][] public allColors = [
    // red
    ["#fee2e2", "#f87171", "#ef4444", "#FF7043", "#D96C75", "#F66A6A"],
    // orange
    ["#ffedd5", "#fb923c", "#f97316", "#FF7E33", "#DA6E40", "#F68942"],
    // amber
    ["#fef3c7", "#fbbf24", "#f59e0b", "#FFAB42", "#D98F2B", "#F6A742"],
    // yellow
    ["#FEF3C7", "#FCD34D", "#F59E0B", "#FFAB42", "#D98F2B", "#F6A742"],
    // lime
    ["#ecfccb", "#a3e635", "#84cc16", "#99E03B", "#7EBF2D", "#8FD842"],
    // green
    ["#dcfce7", "#4ade80", "#22c55e", "#33D96A", "#2BD76E", "#42F66B"],
    // emerald
    ["#d1fae5", "#34d399", "#10b981", "#2BDA99", "#40D6A3", "#42F6B1"],
    // teal
    ["#ccfbf1", "#2dd4bf", "#14b8a6", "#2DDAAB", "#40D6B6", "#42F6C3"],
    // cyan
    ["#cffafe", "#22d3ee", "#06b6d4", "#33D9E6", "#2BD6E9", "#42F6EE"],
    // sky
    ["#e0f2fe", "#38bdf8", "#0ea5e9", "#33D3FF", "#2BCBE9", "#42F1F6"],
    // blue
    ["#dbeafe", "#60a5fa", "#3b82f6", "#254EFB", "#9EB5E1", "#2B83F6"],
    // indigo
    ["#e0e7ff", "#818cf8", "#6366f1", "#4F52FB", "#9F9AE1", "#6E6FF6"],
    // violet
    ["#ede9fe", "#a78bfa", "#8b5cf6", "#7F47FB", "#A999E1", "#8F83F6"],
    // purple
    ["#f3e8ff", "#c084fc", "#a855f7", "#9F42FB", "#B18FE1", "#B073F6"],
    // fuchsia
    ["#fae8ff", "#e879f9", "#d946ef", "#E94FFB", "#DA8EE1", "#F666F6"],
    // pink
    ["#fce7f3", "#f472b6", "#ec4899", "#F642BA", "#E18FB5", "#F673C0"],
    // rose
    ["#ffe4e6", "#fb7185", "#f43f5e", "#FB426B", "#E18F91", "#F66274"]
];

     /*==============================================================
     ==                     Random selection fns                   ==
     ==============================================================*/

    function _random(string memory input) internal pure returns (uint256) {
      return uint256(keccak256(abi.encodePacked(input)));
    }

    // tokenId - the tokenId of the NFT
    function _pluckColor(uint256 tokenId) internal view returns (string[] memory) {
      uint256 rand = _random(string(abi.encodePacked("COLORS", tokenId.toString())));
      string[] memory output = allColors[rand % allColors.length];
      return output;
    }
}
