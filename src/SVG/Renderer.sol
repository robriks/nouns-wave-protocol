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

    uint256 colorCount = 0;
    mapping (uint256 => ColorTrio) public colors;

    struct ColorTrio {
        string light;
        string medium;
        string dark;
    }

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
        // string memory output = generateSVG(params);
        // string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Nouns Prop Lot Idea #', params.tokenId.toString(), '", "description": "An NFT recieved for supporting an idea in Nouns Prop Lot.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        // output = string(abi.encodePacked('data:application/json;base64,', json));
        // return output;

        return "";
    }

    function generateNewSVG() public view returns (string memory svg) {
        return
         string(
                abi.encodePacked(
                    constructSVG(),
                    generateTitle(),
                    generateShape(0, 1),
                    generateStats(0),
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

    function generateTitle() private pure returns (string memory svg) {
        return string(
            abi.encodePacked(
                "<rect width='100%' height='250' fill='#FEF3C7'/>",
                "<text x='16' y='56' font-size='48' class='polyDisp' fill='#F59E0B'>Enjoy Nouns with</text>",
                "<text x='16' y='115' font-size='48' class='polyDisp' fill='#F59E0B'>probe.wtf</text>"
            )
        );
    }

    function generateShape(uint256 colorIndex, uint256 shapeIndex) public view returns (string memory) {
        // ColorTrio memory color = colors[colorIndex];
        string memory shape = Badges(badges).getShape(shapeIndex);

        return string(
            abi.encodePacked(
                "<g transform='translate(480, 20)'>",
                "<path d='",
                shape,
                "' fill='#F59E0B'/>",
                "<text x='24' y='55' fill='#FFF' class='polyDisp' font-size='24'>+for</text>"
                "</g>"
            )
        );
    }

    function generateStats(uint256 colorIndex) public view returns (string memory) {
        // ColorTrio memory color = colors[colorIndex];
        return string(
            abi.encodePacked(
                "<g transform='translate(0, 250)'>",
                "<rect x='0' y='0' width='100%' height='110' fill='#FFFFFF'/>",
                "<g transform='translate(0, 16)'>",
                "<text x='16' y='15' fill='#FCD34D' class='dispText'>Total supporters</text>"
                "<line id='dynamic-line' x1='140' y1='10' x2='550' y2='10' stroke='#FCD34D' stroke-width='1' stroke-dasharray='4,2'/>"
                "<text x='584' y='15' fill='#FCD34D' class='dispText' text-anchor='end'>100</text>",
                "</g>",
                "</g>"
            )
        );
        // <g transform='translate(0, 250)'>
        //     <g transform='translate(0, 46)'>
        //         <text x="16" y="15" fill="#FCD34D" class="disp-text">Total yield</text>
        //         <line id="dynamic-line" x1="100" y1="10" x2="550" y2="10" stroke="#FCD34D" stroke-width="1" stroke-dasharray="4,2"/>
        //         <text x="584" y="15" fill="#FCD34D" class="disp-text" text-anchor="end">100</text>
        //     </g>
        //     <g transform='translate(0, 76)'>
        //         <text x="16" y="15" fill="#FCD34D" class="disp-text">Biggest supporter</text>
        //         <line id="dynamic-line" x1="150" y1="10" x2="550" y2="10" stroke="#FCD34D" stroke-width="1" stroke-dasharray="4,2"/>
        //         <text x="584" y="15" fill="#FCD34D" class="disp-text" text-anchor="end">100</text>
        //     </g>
        // </g>
    }

    function addColor(string memory light, string memory medium, string memory dark) public {
        colors[colorCount] = ColorTrio(light, medium, dark);
        colorCount++;
    }

    function batchAddColors(string[][] memory colorArray) public {
        for (uint256 i = 0; i < colorArray.length; i++) {
            addColor(colorArray[i][0], colorArray[i][1], colorArray[i][2]);
        }
    }

    function getColors(uint256 tokenId) external view returns (ColorTrio memory) {
        return colors[tokenId];
    }
}
