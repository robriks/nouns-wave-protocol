// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { IFont } from '../SVG/interfaces/IFont.sol';
import { IIdeaTokenHub } from '../interfaces/IIdeaTokenHub.sol';
import { BadgeStorage } from "./BadgeStorage.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts/contracts/utils/Base64.sol";


/// @title Renderer
/// @notice Provides a function for generating an SVG associated with a PropLot idea
/// inspired by UNI: https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/NFTSVG.sol
contract Renderer is BadgeStorage {
    using Strings for uint256;
    using Strings for uint216;

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

    address public tokenAddress;
    address public polyDisplay;
    address public polyText;
    address public badges;


    constructor(address _tokenAddress, address _polyDisplay, address _polyText) {
        tokenAddress = _tokenAddress;
        /// could deploy these first and hardcode them
        /// (makes it kinda hard to test though...)
        polyDisplay = _polyDisplay;
        polyText = _polyText;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        string memory output = generateSVG(tokenId);
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Nouns Prop Lot Idea #', tokenId.toString(), '", "description": "An NFT recieved for supporting an idea in Nouns Prop Lot.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));
        return output;
    }

    function generateSVG(uint256 tokenId) public view returns (string memory svg) {
        return
         string(
                abi.encodePacked(
                    constructSVG(),
                    generateTitle(tokenId),
                    generateShape(tokenId),
                    generateStats(tokenId),
                    "</svg>"
                )
            );
    }

    function constructSVG() private view returns (string memory) {
        return string(
            abi.encodePacked(
                "<svg width='600' height='360' viewBox='0 0 600 360' xmlns='http://www.w3.org/2000/svg' shape-rendering='crispEdges'"
                " xmlns:xlink='http://www.w3.org/1999/xlink'>",
                   "<style type='text/css'>"
                   "@font-face {"
                   "font-family: 'PolyDisplay';"
                   "font-style: normal;"
                   "src:url(",
                   IFont(polyDisplay).getFont(),
                   ");}"
                   ".polyDisp {"
                   "font-family: 'PolyDisplay';"
                   "}"
                   "@font-face {"
                   "font-family: 'PolyText';"
                   "font-style: normal;"
                   "src:url(",
                   IFont(polyText).getFont(),
                   ");}"
                   ".polyText {"
                   "font-family: 'PolyText';"
                   "}"
                   "</style>"
            )
        );
    }

    function generateTitle(uint256 tokenId) private view returns (string memory svg) {
        string[] memory colors = _pluckColor(tokenId);
        return string(
            abi.encodePacked(
                "<rect width='100%' height='250' fill='",
                colors[0],
                "'/>",
                "<text x='16' y='56' font-size='48' class='polyDisp' fill='",
                colors[2],
                "'>Wave protocol</text>",
                "<text x='16' y='115' font-size='48' class='polyDisp' fill='",
                colors[2],
                "'>Idea #",
                tokenId.toString(),
                "</text>"
            )
        );
    }

    // public because we want people to be able to see just the "badge"
    function generateShape(uint256 tokenId) public view returns (string memory) {
        string[] memory colors = _pluckColor(tokenId);
        string memory shape = _pluckShape(tokenId);

        return string(
            abi.encodePacked(
                "<g transform='translate(480, 20)'>",
                "<path d='",
                shape,
                "' fill='",
                colors[2],
                "'/>",
                "<text x='24' y='55' fill='#FFF' class='polyText' font-size='24'>+for</text>"
                "</g>"
            )
        );
    }

    function generateStats(uint256 tokenId) internal view returns (string memory) {
        string[] memory colors = _pluckColor(tokenId);
        IdeaInfo memory idea = IIdeaTokenHub(tokenAddress).getIdeaInfo(tokenId);
        return string(
            abi.encodePacked(
                "<g transform='translate(0, 250)'>",
                "<rect x='0' y='0' width='100%' height='110' fill='#FFFFFF'/>",
                "<g transform='translate(0, 16)'>",
                generateStatLine("Total yield", 100, colors[1]),
                "</g>",
                "<g transform='translate(0, 46)'>",
                generateStatLine("Total supply", 100, colors[1]),
                "</g>",
                "<g transform='translate(0, 76)'>",
                generateStatLine("Total whatever", 100, colors[1]),
                "</g>",
                "</g>"
            )
        );
    }

    function generateStatLine(string memory label, uint256 value, string memory color) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "<text x='16' y='15' fill='",
                color,
                "' class='polyText'>",
                label,
                "</text>"
                "<line id='dynamic-line' x1='140' y1='10' x2='550' y2='10' stroke='",
                color,
                "' stroke-width='1' stroke-dasharray='4,2'/>"
                "<text x='584' y='15' fill='",
                color,
                "' class='polyText' text-anchor='end'>",
                value.toString(),
                "</text>"
            ));
    }

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

    function _pluckShape(uint256 tokenId) internal view returns (string memory) {
      uint256 rand = _random(string(abi.encodePacked("SHAPE", tokenId.toString())));
      return getShape(rand);
    }
}
