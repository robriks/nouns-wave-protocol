// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {FontRegistry} from "FontRegistry/src/FontRegistry.sol";
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
    UUPSUpgradeable ideaTokenHubProxy = UUPSUpgradeable(payable(0x54a488958D1f7e90aC1a9C7eE5a450d1E2170789));
    UUPSUpgradeable waveCoreProxy = UUPSUpgradeable(payable(0x55C7c4ADEd315FF29a336cAE5671a4B0A69ae348));

    IdeaTokenHub newIdeaTokenHubImpl;
    IdeaTokenHubHarness ideaTokenHubHarness;
    WaveHarness newWaveCoreImpl;
    FontRegistry fontRegistry;
    Renderer renderer;

    function run() external {
        vm.startBroadcast();

        // deploy new impls
        // fontRegistry = new FontRegistry();
        // renderer = new Renderer(address(fontRegistry));
        newIdeaTokenHubImpl = new IdeaTokenHub();
        // newWaveCoreImpl = new WaveHarness();

        // harness can be used to resolve storage collisions
        ideaTokenHubHarness = new IdeaTokenHubHarness();
        ideaTokenHubProxy.upgradeTo(address(ideaTokenHubHarness));
        IdeaTokenHubHarness(address(ideaTokenHubProxy)).setNextIdeaId(10);
        IdeaTokenHubHarness(address(ideaTokenHubProxy)).setCurrentWaveId(18);

        ideaTokenHubProxy.upgradeTo(address(newIdeaTokenHubImpl));
        // waveCoreProxy.upgradeTo(address(newWaveCoreImpl));

        // for when proxy has already been initialized without renderer
        // IdeaTokenHub(address(ideaTokenHubProxy)).setRenderer(address(renderer));

        vm.stopBroadcast();
    }
}
