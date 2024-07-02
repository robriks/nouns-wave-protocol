// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Wave} from "src/Wave.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";

/// Usage:
/// `forge script script/UpgradeDeployment.s.sol --fork-url $BASE_SEPOLIA_RPC_URL --private-key $PK --with-gas-price 1000000 --verify --etherscan-api-key $BASESCAN_API_KEY --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --broadcast`

/// @dev Script to upgrade existing testnet deployments of the IdeaTokenHub and Wave harness
/// @notice Must be called by the owner address
contract UpgradeDeploymentScript is Script {
    /// @notice Double check below config is correct!
    UUPSUpgradeable ideaTokenHubProxy = UUPSUpgradeable(payable(0x54a488958D1f7e90aC1a9C7eE5a450d1E2170789));
    UUPSUpgradeable waveCoreProxy = UUPSUpgradeable(payable(0x55C7c4ADEd315FF29a336cAE5671a4B0A69ae348));

    IdeaTokenHub newIdeaTokenHubImpl;
    WaveHarness newWaveCoreImpl;

    function run() external {
        vm.startBroadcast();

        // deploy new impls
        newIdeaTokenHubImpl = new IdeaTokenHub();
        newWaveCoreImpl = new WaveHarness();

        ideaTokenHubProxy.upgradeTo(address(newIdeaTokenHubImpl));
        waveCoreProxy.upgradeTo(address(newWaveCoreImpl));
    }
}
