// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { IIdeaTokenHub } from '../interfaces/IIdeaTokenHub.sol';
import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts/contracts/utils/Base64.sol";

/// @title Renderer
/// @notice Provides a function for generating an SVG associated with a PropLot idea
/// inspired by UNI: https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/NFTSVG.sol
contract Renderer {
    using Strings for uint256;
    using Strings for uint216;

    struct SVGParams {
        uint256 tokenId;
        string color;
    }

    // don"t actually need this here, just need it for spiking out the leaderboard
    // I imagine the IdeaTokenHub would implement this...
     struct Sponsor {
        address sponsor;
        uint216 contributedBalance;
    }

    address public tokenAddress;

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function tokenURI(SVGParams memory params) external view returns (string memory) {
        string memory output = generateSVG(params);
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Nouns Prop Lot Idea #', params.tokenId.toString(), '", "description": "An NFT recieved for supporting an idea in Nouns Prop Lot.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));
        return output;
    }

    function generateSVG(SVGParams memory params) internal view returns (string memory svg) {
        return
            string(
                abi.encodePacked(
                    generateSVGDefs(params),
                    generateSVGBody(params),
                    "</svg>"
                )
            );
    }

    function generateSVGDefs(SVGParams memory params) private view returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                "<svg width='290' height='500' viewBox='0 0 290 500' xmlns='http://www.w3.org/2000/svg' shape-rendering='crispEdges'",
                " xmlns:xlink='http://www.w3.org/1999/xlink'>",
                "<defs>",
                "<style>",
                "@import url('https://fonts.googleapis.com/css?family=IBM+Plex+Mono:400,400i,700,700i');",
                " .left { fill: #ffffff70; }",
                " .right { fill: #fff; text-anchor: end; }",
                "</style>",
                "</defs>",
                "<rect width='100%' height='100%' rx='15' fill='#",
                 params.color,
                "'/>"
            ));
    }

    function generateSVGBody(SVGParams memory params) private view returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                "<g transform='translate(10, 10)'>",
                "<rect width='270' height='480' rx='12' fill='#FFFFFF12' />",
                // generateNounsGlasses(),
                generateHeader(params.tokenId),
                generateTitle(params.tokenId),
                generateLeaderboard(params.tokenId),
                "</g>"
            )
        );
    }

    function generateHeader(uint256 tokenId) private view returns (string memory svg) {
        svg = string(
            abi.encodePacked(
                "<g transform='translate(0, 0)'>",
                "<text x='20' y='35' font-family='IBM Plex Mono' font-size='16' fill='white'>NOUNS DAO LOT</text>",
                "<text x='20' y='50' font-family='IBM Plex Mono' font-size='10' fill='white' opacity='.7'>NOUNS.DAO.LOT/IDEA-",
                tokenId.toString(),
                "</text>"
                "</g>"
            )
        );
    }

    function generateTitle(uint256 tokenId) private view returns (string memory svg) {
        // IIdeaTokenHub.IdeaInfo memory details = IIdeaTokenHub(tokenAddress).getIdeaInfo(tokenId);
        // string memory description = details.proposal.description;

        // placeholder
        string memory description = 'Here is the great idea';
        svg = string(
            abi.encodePacked(
                "<g transform='translate(0, 80)'>",
                "<text x='20' y='35' font-family='IBM Plex Mono' font-size='16' fill='white' opacity='.7'>IDEA</text>",
                "<g transform='translate(10, 50)'>",
                "<rect width='250' height='40' rx='6' fill='#FFFFFF10'/>",
                "<path id='textPathCurve' d='M 10 26 L 240 26' />",
                "<text font-family='IBM Plex Mono' fill='white'>",
                "<textPath href='#textPathCurve' startOffset='0%'>",
                description,
                "<animate attributeName='startOffset' from='100%' to='-150%' begin='0s' dur='10s' repeatCount='indefinite'></animate>",
                "</textPath>",
                "</text>",
                "</g>",
                "</g>"
            )
        );
    }

    function generateLeaderboard(uint256 tokenId) private view returns (string memory svg) {

        // mock data -- replace with some function call like
        // Sponsor[] memory leaders = IIdeaTokenHub(tokenAddress).getLeaderboard(tokenId);
        // this should return max 5 for layout reasons
        Sponsor[] memory leaders = new Sponsor[](5);
        leaders[0] = Sponsor({sponsor: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, contributedBalance: 500});
        leaders[1] = Sponsor({sponsor: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, contributedBalance: 400});
        leaders[2] = Sponsor({sponsor: 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db, contributedBalance: 300});
        leaders[3] = Sponsor({sponsor: 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB, contributedBalance: 200});
        leaders[4] = Sponsor({sponsor: 0x617F2E2fD72FD9D5503197092aC168c91465E7f2, contributedBalance: 100});

        // each leader requires 2 lines of svg
        string[] memory parts = new string[](leaders.length * 2);

        for (uint256 index = 0; index < leaders.length; index++) {
            Sponsor memory leader = leaders[index];
            uint256 y = 20 + index*20;
            uint256 offset = index*2;
            string memory sponsor = Strings.toHexString(uint256(uint160(leader.sponsor)), 20);


            parts[offset] = string(abi.encodePacked("<text x='20' y='",y.toString(),"' font-family='IBM Plex Mono' font-size='10' fill='white' opacity='.7' class='left'>",sponsor,"</text>"));
            parts[offset + 1] = string(abi.encodePacked("<text x='250' y='",y.toString(),"' font-family='IBM Plex Mono' font-size='16' fill='white' class='right'>",leader.contributedBalance.toString(),"</text>"));
        }

        bytes memory innerContent;
        for (uint256 i = 0; i < parts.length; i++) {
            innerContent = abi.encodePacked(innerContent, parts[i]);
        }

        svg = string(
            abi.encodePacked(
                "<g transform='translate(0, 360)'>",
                innerContent,
                "</g>"
            )
        );
    }
}
