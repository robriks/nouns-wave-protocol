// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { IFont } from '../SVG/interfaces/IFont.sol';
import { IIdeaTokenHub } from '../interfaces/IIdeaTokenHub.sol';
import { Badges } from "./Badges.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts/contracts/utils/Base64.sol";


/// @title Renderer
/// @notice Provides a function for generating an SVG associated with a PropLot idea
/// inspired by UNI: https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/NFTSVG.sol
contract Renderer {
    using Strings for uint256;
    using Strings for uint216;

    string[][] public allColors = [
        // yellow
        ["#FEF3C7", "#FCD34D", "#F59E0B"],
        // green
        ["#dcfce7", "#4ade80", "#22c55e"]
    ];

    address public tokenAddress;
    address public polyDisplay;
    address public polyText;
    address public badges;


    constructor(address _tokenAddress, address _polyDisplay, address _polyText, address _badges) {
        tokenAddress = _tokenAddress;
        polyDisplay = _polyDisplay;
        polyText = _polyText;
        /// would "is badges" be better (renderer inherits badges)
        badges = _badges;
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

    // function splitTitle(string memory title) private view returns (string[] memory) {
    //     return ["Enjoy Nouns with", "probe.wtf"];
    // }

    function generateTitle(uint256 tokenId) private view returns (string memory svg) {
        string memory title = "Enjoy Nouns with probe.wtf";
        // string memory title = "Heal Noun O'Clock; Full Spec and Economic Audit of % Exit, An Arbitrage-Free Forking Mechanic";


        string[] memory colors = _pluckColor(tokenId);
        return string(
            abi.encodePacked(
                "<rect width='100%' height='250' fill='",
                colors[0],
                "'/>",
                "<text x='16' y='56' font-size='48' class='polyDisp' fill='",
                colors[2],
                "'>Enjoy Nouns with</text>",
                "<text x='16' y='115' font-size='48' class='polyDisp' fill='",
                colors[2],
                "'>probe.wtf</text>"
            )
        );
    }

    function generateShape(uint256 tokenId) public view returns (string memory) {
        string[] memory colors = _pluckColor(tokenId);
        string memory shape = Badges(badges).getShape(0);

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

    function generateStats(uint256 tokenId) public view returns (string memory) {
        string[] memory colors = _pluckColor(tokenId);
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

    function generateStatLine(string memory label, uint256 value, string memory color) public view returns (string memory) {
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
}
