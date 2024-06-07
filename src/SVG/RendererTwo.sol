// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { IFont } from '../SVG/interfaces/IFont.sol';
import { INounsDescriptorV2 } from "./interfaces/INounsDescriptorV2.sol";
import { ISVGRenderer } from "./interfaces/ISVGRenderer.sol";
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";


contract RendererTwo {
    using Strings for uint256;

    address public descriptor = 0x6229c811D04501523C6058bfAAc29c91bb586268;
    address public svgRenderer = 0x81d94554A4b072BFcd850205f0c79e97c92aab56;
    address public tokenAddress;
    address public polyDisplay;
    address public polyText;

    constructor(address _tokenAddress, address _polyDisplay, address _polyText) {
        tokenAddress = _tokenAddress;
        /// could deploy these first and hardcode them
        /// (makes it kinda hard to test though...)
        polyDisplay = _polyDisplay;
        polyText = _polyText;
    }

    function generateSVG(uint256 tokenId) public view returns (string memory svg) {
        return
         string.concat(
                constructSVG(),
                addWaves(),
                generateTitle(tokenId),
                addFooter(tokenId),
                addBadge(tokenId),
                "</svg>"
            );
    }

    function addDefs() private pure returns (string memory) {
        return string.concat(
            "<defs>",
            "<linearGradient id='gradient' x1='0%' y1='0%' x2='0%' y2='100%'>",
            "<stop offset='0%' style='stop-color:#FFFFFF;stop-opacity:0.4' />",
            "<stop offset='100%' style='stop-color:#FFFFFF;stop-opacity:0' />",
            "</linearGradient>",
            "<path id='top-semi-circle' d='M 60,100 A 40,40 0 1,1 140,100' />"
            "<path id='bottom-semi-circle' d='M 140,100 A 40,40 0 1,1 60,100' />",
            "</defs>"
        );
    }


    function constructSVG() private view returns (string memory) {
        return string.concat(
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
                   "</style>",
                   addDefs(),
                   "<rect width='100%' height='100%' rx='10' fill='#254EFB' />"
            );
    }

    function generateTitle(uint256 tokenId) private view returns (string memory svg) {
        return string.concat(
                "<text x='16' y='56' font-size='48' class='polyDisp' fill='#FFFFFF' letter-spacing='1.75'>IDEA ",
                tokenId.toString(),
                "</text><text x='16' y='84' font-size='20' class='polyDisp' fill='#FFFFFF' letter-spacing='1.25''>WAVE 12</text>"
            );
    }

    function addFooter(uint256 tokenId) private view returns (string memory) {
        return string.concat(
            "<g transform='translate(10, 270)'>",
            "<rect width='580' height='80' fill='#FFF' rx='8' />",
            "<text x='16' y='40' font-size='16' class='polyText' fill='#00000030' dominant-baseline='middle'>SUPPORT</text>",
            "<rect x='100' y='15' width='100' height='50' fill='#E9EDFE' rx='4' />",
            "<text x='116' y='40' font-size='16' class='polyText' fill='#00000060' dominant-baseline='middle'>0.34 ETH</text>",
            "<rect x='210' y='15' width='100' height='50' fill='#E9EDFE' rx='4' />",
            "<text x='226' y='40' font-size='16' class='polyText' fill='#00000060' dominant-baseline='middle'>12 MINTS</text>",
            "<text x='400' y='40' font-size='16' class='polyText' fill='#00000030' dominant-baseline='middle'>STATUS:</text>",
            "<rect x='470' y='15' width='100' height='50' fill='#E9EDFE' rx='4' />",
            "<text x='490' y='40' font-size='16' class='polyText' fill='#00000060' dominant-baseline='middle'>PASSED</text>",
            "</g>"
        );
    }

    function addBadge(uint256 tokenId) private view returns (string memory) {
        return string.concat(
        "<g transform='translate(460, 20) scale(1.35)'><path d='M40.0356 2.06625C42.9238 -0.688751 47.4669 -0.688751 50.3551 2.06625V2.06625C52.3992 4.01611 55.3679 4.64712 58.0284 3.69726V3.69726C61.7874 2.35518 65.9377 4.20302 67.4557 7.89458V7.89458C68.53 10.5073 70.9854 12.2912 73.8022 12.5056V12.5056C77.7822 12.8085 80.8221 16.1847 80.7073 20.1745V20.1745C80.6261 22.9983 82.1436 25.6267 84.6297 26.9682V26.9682C88.1423 28.8637 89.5462 33.1844 87.8186 36.7826V36.7826C86.5958 39.3292 86.9131 42.3476 88.6386 44.5844V44.5844C91.0766 47.7447 90.6017 52.2629 87.5599 54.8473V54.8473C85.407 56.6765 84.4692 59.5629 85.1357 62.3081V62.3081C86.0775 66.1869 83.806 70.1213 79.976 71.2451V71.2451C77.2653 72.0404 75.2345 74.2959 74.7268 77.0748V77.0748C74.0096 81.0013 70.3341 83.6717 66.3782 83.1405V83.1405C63.5784 82.7645 60.8057 83.999 59.2117 86.3312V86.3312C56.9594 89.6265 52.5156 90.5711 49.1177 88.4768V88.4768C46.7128 86.9945 43.6778 86.9945 41.273 88.4768V88.4768C37.8751 90.5711 33.4313 89.6265 31.179 86.3312V86.3312C29.5849 83.999 26.8123 82.7645 24.0125 83.1405V83.1405C20.0565 83.6717 16.3811 81.0013 15.6638 77.0748V77.0748C15.1562 74.2959 13.1253 72.0404 10.4147 71.2451V71.2451C6.58465 70.1213 4.31311 66.1869 5.25491 62.3081V62.3081C5.92147 59.5629 4.9836 56.6765 2.83076 54.8473V54.8473C-0.211054 52.2629 -0.685937 47.7447 1.75207 44.5844V44.5844C3.47758 42.3476 3.79482 39.3293 2.57207 36.7826V36.7826C0.844411 33.1844 2.2483 28.8637 5.76097 26.9682V26.9682C8.24706 25.6267 9.76457 22.9983 9.68333 20.1745V20.1745C9.56855 16.1847 12.6085 12.8085 16.5884 12.5056V12.5056C19.4052 12.2912 21.8606 10.5073 22.9349 7.89458V7.89458C24.4529 4.20302 28.6032 2.35518 32.3623 3.69726V3.69726C35.0227 4.64712 37.9914 4.01611 40.0356 2.06625V2.06625Z'",
        "fill='#EAB118' stroke='#000' stroke-width='3' />",
        "<path d='M40.0356 2.06625C42.9238 -0.688751 47.4669 -0.688751 50.3551 2.06625V2.06625C52.3992 4.01611 55.3679 4.64712 58.0284 3.69726V3.69726C61.7874 2.35518 65.9377 4.20302 67.4557 7.89458V7.89458C68.53 10.5073 70.9854 12.2912 73.8022 12.5056V12.5056C77.7822 12.8085 80.8221 16.1847 80.7073 20.1745V20.1745C80.6261 22.9983 82.1436 25.6267 84.6297 26.9682V26.9682C88.1423 28.8637 89.5462 33.1844 87.8186 36.7826V36.7826C86.5958 39.3292 86.9131 42.3476 88.6386 44.5844V44.5844C91.0766 47.7447 90.6017 52.2629 87.5599 54.8473V54.8473C85.407 56.6765 84.4692 59.5629 85.1357 62.3081V62.3081C86.0775 66.1869 83.806 70.1213 79.976 71.2451V71.2451C77.2653 72.0404 75.2345 74.2959 74.7268 77.0748V77.0748C74.0096 81.0013 70.3341 83.6717 66.3782 83.1405V83.1405C63.5784 82.7645 60.8057 83.999 59.2117 86.3312V86.3312C56.9594 89.6265 52.5156 90.5711 49.1177 88.4768V88.4768C46.7128 86.9945 43.6778 86.9945 41.273 88.4768V88.4768C37.8751 90.5711 33.4313 89.6265 31.179 86.3312V86.3312C29.5849 83.999 26.8123 82.7645 24.0125 83.1405V83.1405C20.0565 83.6717 16.3811 81.0013 15.6638 77.0748V77.0748C15.1562 74.2959 13.1253 72.0404 10.4147 71.2451V71.2451C6.58465 70.1213 4.31311 66.1869 5.25491 62.3081V62.3081C5.92147 59.5629 4.9836 56.6765 2.83076 54.8473V54.8473C-0.211054 52.2629 -0.685937 47.7447 1.75207 44.5844V44.5844C3.47758 42.3476 3.79482 39.3293 2.57207 36.7826V36.7826C0.844411 33.1844 2.2483 28.8637 5.76097 26.9682V26.9682C8.24706 25.6267 9.76457 22.9983 9.68333 20.1745V20.1745C9.56855 16.1847 12.6085 12.8085 16.5884 12.5056V12.5056C19.4052 12.2912 21.8606 10.5073 22.9349 7.89458V7.89458C24.4529 4.20302 28.6032 2.35518 32.3623 3.69726V3.69726C35.0227 4.64712 37.9914 4.01611 40.0356 2.06625V2.06625Z'",
        "fill='url(#gradient)' />",
        "</g>"
        "<g transform='translate(421, -19)'>",
        addBadgeText(tokenId),
        "</g>"
        );
    }

    function addBadgeText(uint256 tokenId) private view returns (string memory) {
        return string.concat(
            "<text x='0' y='0' font-size='12' fill='#FFF' class='polyText'>",
                "<textPath href='#top-semi-circle' startOffset='50%' text-anchor='middle'>I support idea 123</textPath>",
            "</text>",
            "<text x='0' y='0' font-size='12' fill='#FFF' class='polyText'>",
                "<textPath href='#bottom-semi-circle' startOffset='50%' text-anchor='middle'>I support idea 123</textPath>",
            "</text>"
        );
    }

    function addWaves() public view returns (string memory) {
        return string.concat(
                addWave(".3", "100", "590"),
                addWave(".3", "700", "610"),
                addWave(".3", "1400", "630"),
                addWave(".3", "450", "350"),
                addWave(".3", "800", "350"),
                addWave(".3", "1200", "350"),
                addWave(".3", "400", "100"),
                addWave(".3", "800", "100"),
                addWave(".3", "1200", "100")
            );

    }

    function addWave(string memory scale, string memory xPos, string memory yPos) public view returns (string memory) {
        bytes memory palette = INounsDescriptorV2(descriptor).palettes(0);
        bytes memory head = INounsDescriptorV2(descriptor).heads(225);
        string memory wave = ISVGRenderer(svgRenderer).generateSVGPart(ISVGRenderer.Part(head, palette));
        return string(
            abi.encodePacked(
                "<g transform='scale(",
                scale,
                ") translate(",
                xPos,
                ", ",
                yPos,
                ")'>",
                wave,
                "'/></g>"
            )
        );
    }
}
