// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Wave} from "src/Wave.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";

contract CreateIdeas is Script {
    /// @notice Harness contract is used on testnet ONLY
    WaveHarness waveCore;
    IdeaTokenHub ideaTokenHub;
    IERC721Checkpointable nounsToken;

    string uri;
    NounsDAOV3Proposals.ProposalTxs txs;
    string description;
    IWave.Proposal[] proposals;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address frog = 0x65A3870F48B5237f27f674Ec42eA1E017E111D63;

        vm.startBroadcast(deployerPrivateKey);

        uri = "someURI";
        waveCore = WaveHarness(0x92bc9f0D42A3194Df2C5AB55c3bbDD82e6Fb2F92);
        ideaTokenHub = IdeaTokenHub(address(waveCore.ideaTokenHub()));
        nounsToken = IERC721Checkpointable(0x9B786579B3d4372d54DFA212cc8B1589Aaf6DcF3);

        // setup mock proposal
        // txs.targets.push(address(0x0));
        // txs.values.push(1);
        // txs.signatures.push("");
        // txs.calldatas.push("");
        // description = "test";

        // minting & transferring
        // NounsTokenHarness(address(nounsToken)).mintMany(0x65A3870F48B5237f27f674Ec42eA1E017E111D63, 25);
        // NounsTokenHarness(address(nounsToken)).mintMany(0x5d5d4d04B70BFe49ad7Aac8C4454536070dAf180, 25);
        NounsTokenHarness(address(nounsToken)).transferFrom(deployer, frog, 1);

        // idea stuff
        // ideaTokenHub.createIdea{value: 0.0001 ether}(txs, description);
        // ideaTokenHub.sponsorIdea{value: 0.0001 ether}(1);

        // Wave delegate events
        // (address targetProxy, uint256 votes) = waveCore.getSuitableDelegateFor(deployer);
        // console2.logUint(votes);
        // assert(targetProxy == waveCore.getDelegateAddress(1));
        // nounsToken.delegate(targetProxy);

        vm.stopBroadcast();
    }
}
