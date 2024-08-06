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

// create2crunch outputs:
// 0x00000000000000000000000000000000000000003d1ee0b1bdc9bf3a9adfff25 => 0x000000000088b111eA8679dD42f7D55512fD6bE8 => 65536
// 0x0000000000000000000000000000000000000000117c2f437759773b67bd7424 => 0x00000000008DDB753b2dfD31e7127f4094CE5630 => 65536

contract Deploy is Script {

    address nounsGovernorProxy = 0x6f3E6272A167e8AcCb32072d08E0957F9c79223d;
    address nounsToken = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;

    address safe = 0x8c3aB329f3e5b43ee37ff3973b090F6A4a5Edf6c; // owner
    uint256 minSponsorshipAmount = 0.000777 ether;
    uint256 waveLength = 50400; // 60hr updatablePeriod + 12hr votingDelay + 96hr votingPeriod
    string polyText;

    IdeaTokenHub ideaTokenHubImpl; // 0x07D6a889B13fC5784e0a73335c36fd3e5db5a5bb
    Wave waveCoreImpl; // 0x62174fc3684ce4dff3d75d2465e3b8ddb44534c2
    IPolymathTextRegular polymathTextRegular; // 0xf3A20995C9dD0F2d8e0DDAa738320F2C8871BD2b
    Renderer renderer; // 0x65DBB4C59d4D5d279beec6dfdb169D986c55962C

    NounsDescriptorV2 nounsDescriptor = NounsDescriptorV2(0x6229c811D04501523C6058bfAAc29c91bb586268);
    SVGRenderer nounsRenderer = SVGRenderer(0x81d94554A4b072BFcd850205f0c79e97c92aab56);

    // uses arachnid deterministic deployment factory
    bytes32 ideaTokenHubImplSalt = keccak256(bytes("IDEATOKENHUB"));
    bytes32 waveCoreImplSalt = keccak256(bytes("WAVE"));
    bytes32 polymathSalt = keccak256(bytes("POLYMATH"));
    bytes32 rendererSalt = keccak256(bytes("RENDERER"));

    // uses create2crunch deterministic deployment factory
    address create2Factory = 0x0000000000FFe8B47B3e2130213B802212439497;
    bytes32 ideaTokenHubSalt = bytes32(uint256(0x3d1ee0b1bdc9bf3a9adfff25));
    bytes32 waveCoreSalt = bytes32(uint256(0x117c2f437759773b67bd7424));
    address ideaTokenHubExpected = 0x000000000088b111eA8679dD42f7D55512fD6bE8;
    address waveCoreExpected = 0x00000000008DDB753b2dfD31e7127f4094CE5630;
    IdeaTokenHub ideaTokenHub;
    Wave waveCore;

    function run() external {
        vm.startBroadcast();

        // deploy PolymathText font and provide it to Renderer constructor on deployment
        string memory root = vm.projectRoot();
        string memory fontPath = string.concat(root, "/test/helpers/font.json");
        string memory fontJson = vm.readFile(fontPath);
        Font memory polyFont = abi.decode(vm.parseJson(fontJson), (Font));
        polyText = polyFont.data;
        polymathTextRegular = IPolymathTextRegular(address(new PolymathTextRegular{salt: polymathSalt}(polyText)));

        renderer = new Renderer{salt: rendererSalt}(polymathTextRegular, address(nounsDescriptor), address(nounsRenderer));

        // deploy Wave contract implementations
        ideaTokenHubImpl = new IdeaTokenHub{salt: ideaTokenHubImplSalt}();
        waveCoreImpl = new Wave{salt: waveCoreImplSalt}();

        // deploy hub proxy using create2crunch
        bytes memory proxyCreationCode = type(ERC1967Proxy).creationCode;
        bytes memory hubConstructorParams = abi.encode(address(ideaTokenHubImpl), '');
        bytes memory ideaTokenHubCreationCode = abi.encodePacked(proxyCreationCode, hubConstructorParams);
        bytes memory hubCreationCall = abi.encodeWithSignature("safeCreate2(bytes32,bytes)", ideaTokenHubSalt, ideaTokenHubCreationCode);
        (bool r, bytes memory ret) = create2Factory.call(hubCreationCall);
        require(r);
        address ideaTokenHubActual = abi.decode(ret, (address));
        ideaTokenHub = IdeaTokenHub(ideaTokenHubActual);

        // deploy wave proxy using create2crunch
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
        bytes memory waveConstructorParams = abi.encode(uint256(uint160(address(waveCoreImpl))), initData);
        bytes memory waveCreationCode = abi.encodePacked(proxyCreationCode, waveConstructorParams);
        bytes memory waveCreationCall = abi.encodeWithSignature("safeCreate2(bytes32,bytes)", waveCoreSalt, waveCreationCode);
        (bool rw, bytes memory retw) = create2Factory.call(waveCreationCall);
        require(rw);
        address waveCoreActual = abi.decode(retw, (address)); 
        waveCore = Wave(waveCoreActual);

        vm.stopBroadcast();

        // asserts
        assert(ideaTokenHubActual == ideaTokenHubExpected);
        assert(waveCoreActual == waveCoreExpected);
        assert(ideaTokenHub.owner() == safe);
        assert(waveCore.owner() == safe);

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