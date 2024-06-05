// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract ColorStorage {
    using Strings for uint256;

    string[][] public allColors = [
        // yellow
        ["#FEF3C7", "#FCD34D", "#F59E0B"],
        // green
        ["#dcfce7", "#4ade80", "#22c55e"],
        // cyan
        ["#cffafe", "#22d3ee", "#06b6d4"],
        // sky
        ["#e0f2fe", "#38bdf8", "#0ea5e9"],
        // blue
        ["#dbeafe", "#60a5fa", "#3b82f6"],
        // indigo
        ["#e0e7ff", "#818cf8", "#6366f1"],
        // violet
        ["#ede9fe", "#a78bfa", "#8b5cf6"],
        // purple
        ["#f3e8ff", "#c084fc", "#a855f7"],
        // fuchsia
        ["#fae8ff", "#e879f9", "#d946ef"],
        // pink
        ["#fce7f3", "#f472b6", "#ec4899"],
        // rose
        ["#ffe4e6", "#fb7185", "#f43f5e"]
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
