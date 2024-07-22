// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV4} from "src/interfaces/INounsDAOLogicV4.sol";
import {NounsDAOStorage} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {NounsDAOProposals} from "nouns-monorepo/governance/NounsDAOProposals.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {ProposalValidatorLib} from "src/lib/ProposalValidatorLib.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";
import {NounsEnvSetup} from "test/helpers/NounsEnvSetup.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

/// @dev This IdeaTokenHub test suite inherits from the Nouns governance setup contract to mimic the onchain environment
contract DelegateTest is NounsEnvSetup, TestUtils {
    INounsDAOLogicV4 nounsGovernor;
    IdeaTokenHub ideaTokenHubImpl;
    IdeaTokenHub ideaTokenHub;
    WaveHarness waveCoreImpl;
    WaveHarness waveCore;
    Delegate delegate;

    // initial pre-update proposal
    uint256 nounsProposalId;
    ProposalTxs txs;
    string description;
    // different proposal to test updates
    ProposalTxs updatedTxs;
    string updatedDescription;
    string updateMessage;

    function setUp() public {
        // establish clone of onchain Nouns governance environment
        super.setUpNounsGovernance();
        super.mintMirrorBalances();

        nounsGovernor = INounsDAOLogicV4(address(nounsGovernorProxy));

        // setup Wave contracts, Renderer discarded
        ideaTokenHubImpl = new IdeaTokenHub();
        ideaTokenHub = IdeaTokenHub(address(new ERC1967Proxy(address(ideaTokenHubImpl), "")));
        waveCoreImpl = new WaveHarness();
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

        // setup mock updated proposal
        updatedTxs.targets.push(address(0x1));
        updatedTxs.values.push(42);
        updatedTxs.signatures.push("");
        updatedTxs.calldatas.push("");
        updatedDescription = "deadbeef";
        updateMessage = "c0ffeebabe";

        // provide funds for `txs` value
        vm.deal(address(this), 1 ether);

        // mint current `proposalThreshold` to the delegate so it can propose
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(delegate), 2);
        vm.roll(block.number + 1);

        // push a proposal to be edited
        vm.prank(address(waveCore));
        nounsProposalId = delegate.pushProposal(nounsGovernor, txs, description);
    }

    function test_updateProposal() public {
        // update the proposal
        vm.expectEmit(true, true, true, true);
        emit NounsDAOProposals.ProposalUpdated(
            nounsProposalId,
            address(delegate),
            updatedTxs.targets,
            updatedTxs.values,
            updatedTxs.signatures,
            updatedTxs.calldatas,
            updatedDescription,
            updateMessage
        );
        vm.prank(address(waveCore));
        delegate.updateProposal(nounsGovernor, nounsProposalId, updatedTxs, updatedDescription, updateMessage);
    }

    function test_updateProposalDescription() public {
        // update the proposal description only by providing empty txs
        ProposalTxs memory emptyTxs = ProposalTxs(new address[](0), new uint256[](0), new string[](0), new bytes[](0));
        vm.expectEmit(true, true, true, true);
        emit NounsDAOProposals.ProposalDescriptionUpdated(
            nounsProposalId, address(delegate), updatedDescription, updateMessage
        );
        vm.prank(address(waveCore));
        delegate.updateProposal(nounsGovernor, nounsProposalId, emptyTxs, updatedDescription, updateMessage);
    }

    function test_updateProposalTxs() public {
        // update the proposal txs only by providing description
        vm.expectEmit(true, true, true, true);
        emit NounsDAOProposals.ProposalTransactionsUpdated(
            nounsProposalId,
            address(delegate),
            updatedTxs.targets,
            updatedTxs.values,
            updatedTxs.signatures,
            updatedTxs.calldatas,
            updateMessage
        );
        vm.prank(address(waveCore));
        delegate.updateProposal(nounsGovernor, nounsProposalId, updatedTxs, "", updateMessage);
    }

    function test_revertUpdateProposalArityMismatch() public {
        // revert by providing mismatching arity
        ProposalTxs memory badTxs = ProposalTxs(new address[](0), new uint256[](1), new string[](2), new bytes[](3));
        vm.expectRevert(ProposalValidatorLib.ProposalInfoArityMismatch.selector);
        vm.prank(address(waveCore));
        delegate.updateProposal(nounsGovernor, nounsProposalId, badTxs, updatedDescription, updateMessage);
    }

    function test_cancelProposal() public {
        vm.expectEmit();
        emit NounsDAOProposals.ProposalCanceled(nounsProposalId);
        vm.prank(address(waveCore));
        delegate.cancelProposal(nounsGovernor, nounsProposalId);
    }
}