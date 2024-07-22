// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NounsDAOProposals} from "nouns-monorepo/governance/NounsDAOProposals.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {NounsDescriptorV2} from "nouns-monorepo/NounsDescriptorV2.sol";
import {SVGRenderer} from "nouns-monorepo/SVGRenderer.sol";
import {PolymathTextRegular} from "src/SVG/fonts/PolymathTextRegular.sol";
import {IPolymathTextRegular} from "src/SVG/fonts/IPolymathTextRegular.sol";
import {Font} from "test/svg/HotChainSVG.t.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Wave} from "src/Wave.sol";
import {Renderer} from "src/SVG/Renderer.sol";
import {NounsConfigData} from "test/helpers/NounsEnvSetup.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";

/// @dev Deploys and adds the polymath-text font to Wave Protocol's Renderer contract
/// @notice Can be tweaked to add the polymath-text font to the 0xBeans FontRegistry when deployed
contract DeployFontAndRenderer is Script {
    IPolymathTextRegular polymathTextRegular;
    Renderer renderer;

    /// @dev <= v1.5
    // waveCore = WaveHarness(0x92bc9f0D42A3194Df2C5AB55c3bbDD82e6Fb2F92);
    // ideaTokenHub = IdeaTokenHub(address(waveCore.ideaTokenHub()));
    // nounsToken = IERC721Checkpointable(0x9B786579B3d4372d54DFA212cc8B1589Aaf6DcF3);

    /// @notice Harness contract is used on testnet ONLY
    /// @dev >= v1.6 testnet config for mock nouns infra
    WaveHarness waveCore = WaveHarness(0x443f1F80fBB72Fa40cA70A93a0139852b0563961);
    IdeaTokenHub ideaTokenHub = IdeaTokenHub(address(waveCore.ideaTokenHub()));
    IERC721Checkpointable nounsToken = IERC721Checkpointable(0xE8b46D16107e1d562B62B5aA8d4bF9A60e6c51b4);
    NounsDescriptorV2 nounsDescriptor = NounsDescriptorV2(0x6cd473673A73150C8ff9Edc160262EBac3C882c0);
    SVGRenderer nounsSVGRenderer = SVGRenderer(0x09A80D276a4dBb6a400aF1c8663ed0cC2073cFE7);
        
    string polyText;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // testnet descriptor requires palette and head to be set to match mainnet
        string memory root = vm.projectRoot();
        string memory nounsConfigDataPath = string.concat(root, "/test/helpers/nouns-config-data.json");
        string memory nounsConfigDataJson = vm.readFile(nounsConfigDataPath);
        NounsConfigData memory configData = abi.decode(vm.parseJson(nounsConfigDataJson), (NounsConfigData));
                
        nounsDescriptor.setPalette(0, configData.palette0);
        nounsDescriptor.addHeads(configData.encodedCompressedHeadsData, uint40(configData.decompressedLengthOfHeadBytes), uint16(configData.imageCountOfHeads));

        // deploy PolymathText font and provide it to Renderer constructor on deployment
        string memory fontPath = string.concat(root, "/test/helpers/font.json");
        string memory fontJson = vm.readFile(fontPath);
        Font memory polyFont = abi.decode(vm.parseJson(fontJson), (Font));
        polyText = polyFont.data;
        polymathTextRegular = IPolymathTextRegular(address(new PolymathTextRegular(polyText)));

        renderer = new Renderer(polymathTextRegular, address(nounsDescriptor), address(nounsSVGRenderer));

        // in the case of existing IdeaTokenHub deployment, Renderer needs to be set outside of initializer
        ideaTokenHub.setRenderer(address(renderer));
        string memory test = ideaTokenHub.uri(1);
        console2.logString(test);

        vm.stopBroadcast();
    }
}
