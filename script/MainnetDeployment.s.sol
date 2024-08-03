// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NounsDescriptorV2} from "nouns-monorepo/NounsDescriptorV2.sol";
import {SVGRenderer} from "nouns-monorepo/SVGRenderer.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV4} from "src/interfaces/INounsDAOLogicV4.sol";
import {PolymathTextRegular} from "src/SVG/fonts/PolymathTextRegular.sol";
import {IPolymathTextRegular} from "src/SVG/fonts/IPolymathTextRegular.sol";
import {Renderer} from "src/SVG/Renderer.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Wave} from "src/Wave.sol";
import {Font} from "test/svg/HotChainSVG.t.sol";

/// Simulation Usage:
/// `forge script script/MainnetDeployment.s.sol:Deploy --fork-url $MAINNET_RPC_URL --keystore $KS --password $PW --sender $VANITY --verify`

/// Verification:
/* 
`forge verify-contract <renderer> --watch src/SVG/Renderer.sol:Renderer`
`forge verify-contract <ideaTokenHub> --watch src/IdeaTokenHub.sol:IdeaTokenHub`
`forge verify-contract <waveCore> --watch src/Wave.sol:Wave`
*/

contract Deploy is Script {

    address nounsGovernorProxy = 0x6f3E6272A167e8AcCb32072d08E0957F9c79223d;
    address nounsToken = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;

    address safe = 0x8c3aB329f3e5b43ee37ff3973b090F6A4a5Edf6c; // owner
    uint256 minSponsorshipAmount = 0.000777 ether;
    uint256 waveLength = 50400; // 60hr updatablePeriod + 12hr votingDelay + 96hr votingPeriod
    string polyText;

    Wave waveCoreImpl;
    IdeaTokenHub ideaTokenHubImpl;
    IPolymathTextRegular polymathTextRegular;
    Renderer renderer;

    NounsDescriptorV2 nounsDescriptor = NounsDescriptorV2(0x6229c811D04501523C6058bfAAc29c91bb586268);
    SVGRenderer nounsRenderer = SVGRenderer(0x81d94554A4b072BFcd850205f0c79e97c92aab56);

    bytes32 waveCoreSalt = keccak256(bytes("WAVE"));
    bytes32 ideaTokenHubSalt = keccak256(bytes("IDEATOKENHUB"));
    Wave waveCore;
    IdeaTokenHub ideaTokenHub;

    function run() external {
        vm.startBroadcast();

        // deploy PolymathText font and provide it to Renderer constructor on deployment
        string memory root = vm.projectRoot();
        string memory fontPath = string.concat(root, "/test/helpers/font.json");
        string memory fontJson = vm.readFile(fontPath);
        Font memory polyFont = abi.decode(vm.parseJson(fontJson), (Font));
        polyText = polyFont.data;
        polymathTextRegular = IPolymathTextRegular(address(new PolymathTextRegular(polyText)));

        renderer = new Renderer(polymathTextRegular, address(nounsDescriptor), address(nounsRenderer));

        // deploy Wave contract implementations
        ideaTokenHubImpl = new IdeaTokenHub();
        waveCoreImpl = new Wave();

        // deploy proxies pointed at impls
        ideaTokenHub = IdeaTokenHub(address(new ERC1967Proxy{salt: ideaTokenHubSalt}(address(ideaTokenHubImpl), "")));
        bytes memory initData = abi.encodeWithSelector(
            IWave.initialize.selector,
            address(ideaTokenHub),
            address(nounsGovernorProxy),
            address(nounsToken),
            minSponsorshipAmount,
            waveLength,
            address(renderer),
            safe
        );
        waveCore = Wave(address(new ERC1967Proxy{salt: waveCoreSalt}(address(waveCoreImpl), initData)));

        vm.stopBroadcast();

        require(address(polymathTextRegular).code.length > 0);
        require(address(renderer).code.length > 0);
        require(address(ideaTokenHub).code.length > 0);
        require(address(waveCore).code.length > 0);
        console2.logAddress(address(polymathTextRegular));
        console2.logAddress(address(renderer));
        console2.logAddress(address(ideaTokenHub));
        console2.logAddress(address(waveCore));
    }
}