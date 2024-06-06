// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;


import { INounsDescriptorV2 } from "./interfaces/INounsDescriptorV2.sol";
import { ISVGRenderer } from "./interfaces/ISVGRenderer.sol";

contract RendererTwo {

    address public descriptor = 0x6229c811D04501523C6058bfAAc29c91bb586268;
    address public svgRenderer = 0x81d94554A4b072BFcd850205f0c79e97c92aab56;

    function generateSVG(uint256 tokenId) public view returns (string memory svg) {
        return
         string(
            abi.encodePacked(
                constructSVG(),
                addWave(),
                // generateTitle(tokenId),
                // constructWaveScene(tokenId),
                // generateShape(tokenId),
                // generateStats(tokenId),
                "</svg>"
            )
        );
    }

    function constructSVG() private view returns (string memory) {
        return string(
            abi.encodePacked(
                "<svg width='600' height='360' viewBox='0 0 600 360' xmlns='http://www.w3.org/2000/svg' shape-rendering='crispEdges'"
                " xmlns:xlink='http://www.w3.org/1999/xlink'>"
                "<rect width='100%' height='100%' fill='#000000' stroke='#000000' stroke-width='8'/>"
            )
        );
    }

    function addWave() private view returns (string memory) {
        bytes memory palette = INounsDescriptorV2(descriptor).palettes(0);
        bytes memory head = INounsDescriptorV2(descriptor).heads(0);
        return ISVGRenderer(svgRenderer).generateSVGPart(ISVGRenderer.Part(head, palette));
    }
}
