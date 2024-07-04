// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {WaveTest} from "test/Wave.t.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";
import {NounsEnvSetup} from "test/helpers/NounsEnvSetup.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

/// @dev This IdeaTokenHub test suite inherits from the Nouns governance setup contract to mimic the onchain environment
contract DelegateTest is NounsEnvSetup, TestUtils {
    IdeaTokenHub ideaTokenHubImpl;
    IdeaTokenHub ideaTokenHub;
    WaveHarness waveCoreImpl;
    WaveHarness waveCore;
    Delegate delegate;

    ProposalTxs txs;
    string description;
    // singular proposal stored for easier referencing against `IdeaInfo` struct member
    IWave.Proposal proposal;

function setUp() public {
        // establish clone of onchain Nouns governance environment
        super.setUpNounsGovernance();

        // setup Wave contracts, Renderer discarded
        ideaTokenHubImpl = new IdeaTokenHub();
        ideaTokenHub = IdeaTokenHub(address(new ERC1967Proxy(address(ideaTokenHubImpl), "")));        waveCoreImpl = new WaveHarness();
        bytes memory initData = abi.encodeWithSelector(
            IWave.initialize.selector,
            address(ideaTokenHub),
            address(nounsGovernorProxy),
            address(nounsTokenHarness),
            0,
            42,
            address(0x0)
        );
        waveCore = WaveHarness(address(new ERC1967Proxy(address(waveCoreImpl), initData)));
        delegate = Delegate(waveCore.createDelegate());

        // setup mock proposal
        txs.targets.push(address(0x0));
        txs.values.push(1);
        txs.signatures.push("");
        txs.calldatas.push("");
        description = "test";

        // provide funds for `txs` value
        vm.deal(address(this), 1 ether);

        // mint current `proposalThreshold` to the delegate so it can propose
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(delegate), 2);

        // proposal configuration
        proposal = IWave.Proposal(txs, description);
    }

    function test_updatePushedProposal() public {
        //todo
    }
}