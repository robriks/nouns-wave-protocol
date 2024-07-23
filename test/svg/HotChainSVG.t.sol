//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import {Renderer} from "src/SVG/Renderer.sol";
import {PolymathTextRegular} from "src/SVG/fonts/PolymathTextRegular.sol";
import {IPolymathTextRegular} from "src/SVG/fonts/IPolymathTextRegular.sol";

struct Font {
    string data;
}

contract HotChainSVG is Test {
    using stdJson for string;

    IPolymathTextRegular public textRegular;
    Renderer public r;

    string mainnetRPC = vm.envString("MAINNET_RPC_URL");
    uint256 fork = vm.createFork(mainnetRPC);

    // mainnet nouns infra
    address public nounsDescriptor = 0x6229c811D04501523C6058bfAAc29c91bb586268;
    address public nounsSVGRenderer = 0x81d94554A4b072BFcd850205f0c79e97c92aab56;

    function setUp() public {
        vm.selectFork(fork);

        string memory root = vm.projectRoot();
        string memory fontPath = string.concat(root, "/test/helpers/font.json");
        string memory json = vm.readFile(fontPath);
        Font memory polyFont = abi.decode(vm.parseJson(json), (Font));
        string memory polyText = polyFont.data;

        textRegular = IPolymathTextRegular(address(new PolymathTextRegular(polyText)));
        r = new Renderer(textRegular, nounsDescriptor, nounsSVGRenderer);
    }

    function test_HotChainSVG() public {
        vm.selectFork(fork);
        string memory webpage = string.concat("<html>", "<title>Hot Chain SVG</title>", r.generateSVG(442), "</html>");

        vm.writeFile("src/SVG/output/index.html", webpage);
    }
}
