// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Wave} from "src/Wave.sol";

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

    uint256 minSponsorshipAmount = 0.000777 ether;
    uint256 waveLength = 50400; // 60hr updatablePeriod + 12hr votingDelay + 96hr votingPeriod

    Wave waveCoreImpl;
    IdeaTokenHub ideaTokenHubImpl;
    FontRegistry fontRegistry;
    Renderer renderer;

    bytes32 waveCoreSalt = vm.envBytes32("WAVE_CORE_SALT");
    bytes32 ideaTokenHubSalt = vm.envBytes32("IDEATOKENHUB_SALT");
    Wave waveCore;
    IdeaTokenHub ideaTokenHub;

    function run() external {
        vm.startBroadcast();

        // deploy font registry and renderer for dynamic SVG URI generation
        fontRegistry = new FontRegistry();
        renderer = new Renderer(address(fontRegistry));
        require(address(fontRegistry).code.length > 0);
        require(address(renderer).code.length > 0);
        // deploy Wave contract implementations 
        ideaTokenHubImpl = new IdeaTokenHub();
        waveCoreImpl = new Wave();

        // use create2crunch to identify suitable salt for gas-efficient proxy addresses with leading zero bytes
        
        // deploy proxies pointed at impls
        ideaTokenHub = IdeaTokenHub(address(new ERC1967Proxy{salt: ideaTokenHubSalt}(address(ideaTokenHubImpl), "")));
        bytes memory initData = abi.encodeWithSelector(
            IWave.initialize.selector,
            address(ideaTokenHub),
            address(nounsGovernorProxy),
            address(nounsToken),
            minSponsorshipAmount,
            waveLength,
            address(renderer)
        );
        waveCore = Wave(address(new ERC1967Proxy{salt: waveCoreSalt}(address(waveCoreImpl), initData)));

        require(address(ideaTokenHub).code.length > 0);
        require(address(waveCore).code.length > 0);
        console2.logAddress(address(fontRegistry));
        console2.logAddress(address(renderer));
        console2.logAddress(address(ideaTokenHub));
        console2.logAddress(address(waveCore));

        vm.stopBroadcast();
    }
}