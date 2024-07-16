// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {FontRegistry} from "FontRegistry/src/FontRegistry.sol";
import {NounsDescriptorV2} from "nouns-monorepo/NounsDescriptorV2.sol";
import {SVGRenderer} from "nouns-monorepo/SVGRenderer.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Wave} from "src/Wave.sol";
import {Renderer} from "src/SVG/Renderer.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";
import {IdeaTokenHubHarness} from "test/harness/IdeaTokenHubHarness.sol";

/// Usage:
/// `forge script script/UpgradeDeployment.s.sol --fork-url $BASE_SEPOLIA_RPC_URL --private-key $PK --with-gas-price 1000000 --verify --etherscan-api-key $BASESCAN_API_KEY --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --broadcast`

/// @dev Script to upgrade existing testnet deployments of the IdeaTokenHub and Wave harness
/// @notice Must be called by the owner address
contract UpgradeDeploymentScript is Script {
    /// @notice Double check below config is correct!
    UUPSUpgradeable ideaTokenHubProxy = UUPSUpgradeable(payable(0xAFFED3815a60aACeACDA3aE53425f053eD6Efc4d));
    UUPSUpgradeable waveCoreProxy = UUPSUpgradeable(payable(0x443f1F80fBB72Fa40cA70A93a0139852b0563961));
    FontRegistry fontRegistry = FontRegistry(0x765EeF8b5dD7af8FC7Aa03C76aFFd23AbcE7a3Bb);
    NounsDescriptorV2 nounsDescriptor = NounsDescriptorV2(0x6cd473673A73150C8ff9Edc160262EBac3C882c0);
    SVGRenderer nounsSVGRenderer = SVGRenderer(0x09A80D276a4dBb6a400aF1c8663ed0cC2073cFE7);

    IdeaTokenHub newIdeaTokenHubImpl;
    IdeaTokenHubHarness ideaTokenHubHarness;
    WaveHarness newWaveCoreImpl;
    Renderer renderer;

    function run() external {
        vm.startBroadcast();

        // deploy new impls
        renderer = new Renderer(address(fontRegistry), address(nounsDescriptor), address(nounsSVGRenderer));
        newIdeaTokenHubImpl = new IdeaTokenHub();
        // newWaveCoreImpl = new WaveHarness();

        ideaTokenHubProxy.upgradeTo(address(newIdeaTokenHubImpl));
        // waveCoreProxy.upgradeTo(address(newWaveCoreImpl));

        // for new renderer deployments
        IdeaTokenHub(address(ideaTokenHubProxy)).setRenderer(address(renderer));

        vm.stopBroadcast();
    }
}
