// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IPropLot} from "src/interfaces/IPropLot.sol";
import {PropLotTest} from "test/PropLot.t.sol";
import {PropLotHarness} from "test/harness/PropLotHarness.sol";
import {NounsEnvSetup} from "test/NounsEnvSetup.sol";

/// @dev This IdeaTokenHub test suite inherits from the Nouns governance setup contract to mimic the onchain environment
contract IdeaTokenHubTest is NounsEnvSetup {

    PropLotHarness propLot;
    IdeaTokenHub ideaTokenHub;

    string uri;
    NounsDAOV3Proposals.ProposalTxs txs;
    string description;
    // singular proposal stored for easier referencing against `IdeaInfo` struct member
    IPropLot.Proposal proposal;
    IdeaTokenHub.RoundInfo firstRoundInfo; // only used for sanity checks
    
    function setUp() public {
        // establish clone of onchain Nouns governance environment
        super.setUpNounsGovernance();

        // setup PropLot contracts
        uri = 'someURI';
        propLot = new PropLotHarness(INounsDAOLogicV3(address(nounsGovernorProxy)), IERC721Checkpointable(address(nounsTokenHarness)), uri);
        ideaTokenHub = IdeaTokenHub(propLot.ideaTokenHub());

        // setup mock proposal
        txs.targets.push(address(0x0));
        txs.values.push(1);
        txs.signatures.push('');
        txs.calldatas.push('');
        description = 'test';

        // provide funds for `txs` value
        vm.deal(address(this), 1 ether);

        // continue with IdeaTokenHub configuration
        firstRoundInfo.currentRound = 1;
        firstRoundInfo.startBlock = uint32(block.number);
        proposal = IPropLot.Proposal(txs, description);
    }

    function test_setUp() public {
        assertEq(ideaTokenHub.getNextIdeaId(), 1);
        (uint32 currentRound, uint32 startBlock) = ideaTokenHub.currentRoundInfo();
        assertEq(currentRound, firstRoundInfo.currentRound);
        assertEq(startBlock, firstRoundInfo.startBlock);
    }

    // function test_createIdea() public {}
    // function test_sponsorIdea()

    // function test_finalizeAuction() public {}
    // function test_claim()
    // function test_revertTransfer()
    // function test_revertBurn()
    // function test_uri
}