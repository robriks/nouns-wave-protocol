//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import {FontRegistry} from "FontRegistry/src/FontRegistry.sol";
import {Renderer} from "../../src/SVG/Renderer.sol";
import {PolymathTextRegular} from "../../src/SVG/fonts/PolymathTextRegular.sol";

struct Font {
    string data;
}

contract HotChainSVG is Test {
    using stdJson for string;

    PolymathTextRegular public textRegular;
    FontRegistry public fontRegistry;
    Renderer public r;

    string mainnetRPC = vm.envString("MAINNET_RPC_URL");
    uint256 fork = vm.createFork(mainnetRPC);

    function setUp() public {
        vm.selectFork(fork);

        string memory root = vm.projectRoot();
        string memory fontPath = string.concat(root, "/test/helpers/font.json");
        string memory json = vm.readFile(fontPath);
        Font memory polyFont = abi.decode(vm.parseJson(json), (Font));
        string memory polyText = polyFont.data;

        textRegular = new PolymathTextRegular(polyText);
        fontRegistry = new FontRegistry();
        fontRegistry.addFontToRegistry(address(textRegular));
        r = new Renderer(address(fontRegistry));
    }

    function test_HotChainSVG() public {
        vm.selectFork(fork);
        string memory webpage = string.concat("<html>", "<title>Hot Chain SVG</title>", r.generateSVG(442), "</html>");

        vm.writeFile("src/SVG/output/index.html", webpage);
    }
}
