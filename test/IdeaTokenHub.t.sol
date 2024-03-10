// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IIdeaTokenHub} from "src/interfaces/IIdeaTokenHub.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IPropLot} from "src/interfaces/IPropLot.sol";
import {PropLotTest} from "test/PropLot.t.sol";
import {PropLotHarness} from "test/harness/PropLotHarness.sol";
import {NounsEnvSetup} from "test/helpers/NounsEnvSetup.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

/// @dev This IdeaTokenHub test suite inherits from the Nouns governance setup contract to mimic the onchain environment
contract IdeaTokenHubTest is NounsEnvSetup, TestUtils {

    PropLotHarness propLot;
    IdeaTokenHub ideaTokenHub;

    uint256 roundLength;
    uint256 minSponsorshipAmount;
    uint256 decimals;
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
        roundLength = 1209600;//todo
        minSponsorshipAmount = 0.001 ether;
        decimals = 18;
        uri = 'someURI';
        // roll to block number of at least `roundLength` to prevent underflow within `currentRoundInfo.startBlock`
        vm.roll(roundLength);
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

        // balances to roughly mirror mainnet
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsForkEscrow_), 265);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(nounsDAOSafe_, 30);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71, 308);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsTokenHarness), 25);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(0x1), 370); // ~rest of missing supply to dummy address

        // continue with IdeaTokenHub configuration
        firstRoundInfo.currentRound = 1;
        firstRoundInfo.startBlock = uint32(block.number);
        proposal = IPropLot.Proposal(txs, description);
    }

    function test_setUp() public {
        // sanity checks
        assertEq(ideaTokenHub.roundLength(), roundLength);
        assertEq(ideaTokenHub.minSponsorshipAmount(), minSponsorshipAmount);
        assertEq(ideaTokenHub.decimals(), decimals);

        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        (uint32 currentRound, uint32 startBlock) = ideaTokenHub.currentRoundInfo();
        assertEq(currentRound, firstRoundInfo.currentRound);
        assertEq(startBlock, firstRoundInfo.startBlock);

        bytes memory err = abi.encodeWithSelector(IIdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);
    }

    function test_createIdeaEOA(uint64 ideaValue, uint8 numCreators) public {
        vm.assume(numCreators != 0);
        ideaValue = uint64(bound(ideaValue, 0.001 ether, type(uint64).max));
        
        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        
        bytes memory err = abi.encodeWithSelector(IIdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);

        for (uint256 i; i < numCreators; ++i) {
            address nounder = _createNounderEOA(i);
            vm.deal(nounder, ideaValue);

            uint256 currentIdeaId = startId + i;
            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.IdeaCreated(IPropLot.Proposal(txs, description), nounder, uint96(currentIdeaId), IIdeaTokenHub.SponsorshipParams(ideaValue, true));
            
            vm.prank(nounder);
            ideaTokenHub.createIdea{value: ideaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), ideaValue);
        }

        IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(startId);
        assertEq(newInfo.totalFunding, ideaValue);
        assertEq(newInfo.blockCreated, uint32(block.number));
        assertFalse(newInfo.isProposed);
        assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
        assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
        assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
        assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
        assertEq(newInfo.proposal.description, description);
    }

    function test_createIdeaSmartAccount(uint64 ideaValue, uint8 numCreators) public {
        vm.assume(numCreators != 0);
        ideaValue = uint64(bound(ideaValue, 0.001 ether, type(uint64).max));
        
        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        
        bytes memory err = abi.encodeWithSelector(IIdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);

        for (uint256 i; i < numCreators; ++i) {
            uint256 currentIdeaId = startId + i;
            assertEq(ideaTokenHub.getNextIdeaId(), currentIdeaId);

            address nounder = _createNounderSmartAccount(i);
            vm.deal(nounder, ideaValue);

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.IdeaCreated(IPropLot.Proposal(txs, description), nounder, uint96(currentIdeaId), IIdeaTokenHub.SponsorshipParams(ideaValue, true));
            
            vm.prank(nounder);
            ideaTokenHub.createIdea{value: ideaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), ideaValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, ideaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);
        }
    }

    function test_sponsorIdea(uint8 numCreators, uint8 numSponsors) public {
        vm.assume(numSponsors != 0);
        vm.assume(numCreators != 0);
        
        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        
        bytes memory err = abi.encodeWithSelector(IIdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);

        bool eoa;
        for (uint256 i; i < numCreators; ++i) {
            uint256 currentIdeaId = startId + i;
            assertEq(ideaTokenHub.getNextIdeaId(), currentIdeaId);
            // targets 10e15 order; not truly random but appropriate for testing
            uint256 pseudoRandomIdeaValue = uint256(keccak256(abi.encode(i))) / 10e15;

            // alternate between simulating EOA and smart contract wallets
            address nounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);
            vm.deal(nounder, pseudoRandomIdeaValue);

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.IdeaCreated(IPropLot.Proposal(txs, description), nounder, uint96(currentIdeaId), IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomIdeaValue), true));
            
            vm.prank(nounder);
            ideaTokenHub.createIdea{value: pseudoRandomIdeaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), pseudoRandomIdeaValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, pseudoRandomIdeaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);

            eoa = !eoa;
        }

        for (uint256 l; l < numSponsors; ++l) {
            assertEq(ideaTokenHub.getNextIdeaId(), uint256(numCreators) + 1);
            // targets 10e16 order; not truly random but appropriate for testing
            uint256 pseudoRandomSponsorValue = uint256(keccak256(abi.encode(l << 2))) / 10e15;

            // alternate between simulating EOA and smart contract wallets
            address sponsor = eoa ? _createNounderEOA(numCreators + l) : _createNounderSmartAccount(numCreators + l);
            vm.deal(sponsor, pseudoRandomSponsorValue);

            // reduce an entropic hash to the `[0:nextIdeaId]` range via modulo
            uint256 numIds = ideaTokenHub.getNextIdeaId() - 1;
            // add 1 since modulo produces one less than desired range, incl 0
            uint256 pseudoRandomIdeaId = (uint256(keccak256(abi.encode(l))) % numIds) + 1;
            uint256 currentIdTotalFunding = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId).totalFunding; // get existing funding value

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.Sponsorship(sponsor, uint96(pseudoRandomIdeaId), IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomSponsorValue), false));
            
            vm.prank(sponsor);
            ideaTokenHub.sponsorIdea{value: pseudoRandomSponsorValue}(pseudoRandomIdeaId);

            assertEq(ideaTokenHub.balanceOf(sponsor, pseudoRandomIdeaId), pseudoRandomSponsorValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId);
            // check that `IdeaInfo.totalFunding` increased by `pseudoRandomSponsorValue`, ergo `currentTotalFunding`
            currentIdTotalFunding += pseudoRandomSponsorValue;
            assertEq(newInfo.totalFunding, currentIdTotalFunding);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);

            eoa = !eoa;
        }
    }

    function test_finalizeAuction(uint8 numSupplementaryDelegations, uint8 numFullDelegations, uint8 numCreators, uint8 numSponsors) public {
        vm.assume(numSponsors != 0);
        vm.assume(numCreators != 0);
        vm.assume(numFullDelegations != 0 || numSupplementaryDelegations > 1);

        uint256 startMinRequiredVotes = propLot.getCurrentMinRequiredVotes(); // stored for assertions

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // perform supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            // mint `minRequiredVotes / 2` to new nounder and delegate
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);

            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            uint256 returnedSupplementaryBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
            assertEq(returnedSupplementaryBalance, amt);
            
            uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, true);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentSupplementaryNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentSupplementaryNounder, delegateId, amt);
            vm.stopPrank();

            // simulate time passing
            vm.roll(block.number + 200);
            eoa = !eoa;
        }

        // perform full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);

            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes; // amount to mint

            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);
            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, false);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentFullNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentFullNounder, delegateId, amt);
            vm.stopPrank();

            // simulate time passing
            vm.roll(block.number + 200);
            eoa = !eoa;
        }

        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        
        // create ideas
        for (uint256 k; k < numCreators; ++k) {
            uint256 currentIdeaId = startId + k;
            assertEq(ideaTokenHub.getNextIdeaId(), currentIdeaId);
            // targets 10e15 order; not truly random but appropriate for testing
            uint256 pseudoRandomIdeaValue = uint256(keccak256(abi.encode(k))) / 10e15;

            // alternate between simulating EOA and smart contract wallets
            uint256 collisionOffset = k + numSupplementaryDelegations + numFullDelegations; // prevent collisions
            address nounder = eoa ? _createNounderEOA(collisionOffset) : _createNounderSmartAccount(collisionOffset);
            vm.deal(nounder, pseudoRandomIdeaValue);

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.IdeaCreated(IPropLot.Proposal(txs, description), nounder, uint96(currentIdeaId), IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomIdeaValue), true));
            
            vm.prank(nounder);
            ideaTokenHub.createIdea{value: pseudoRandomIdeaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), pseudoRandomIdeaValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, pseudoRandomIdeaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);

            eoa = !eoa;
        }

        // sponsor ideas
        for (uint256 l; l < numSponsors; ++l) {
            assertEq(ideaTokenHub.getNextIdeaId(), uint256(numCreators) + 1);
            // targets 10e16 order; not truly random but appropriate for testing
            uint256 pseudoRandomSponsorValue = uint256(keccak256(abi.encode(l << 2))) / 10e15;

            // alternate between simulating EOA and smart contract wallets
            uint256 collisionOffset = l + numCreators + numSupplementaryDelegations + numFullDelegations;
            address sponsor = eoa ? _createNounderEOA(collisionOffset) : _createNounderSmartAccount(collisionOffset);
            vm.deal(sponsor, pseudoRandomSponsorValue);

            // reduce an entropic hash to the `[0:nextIdeaId]` range via modulo
            uint256 numIds = ideaTokenHub.getNextIdeaId() - 1;
            // add 1 since modulo produces one less than desired range, incl 0
            uint256 pseudoRandomIdeaId = (uint256(keccak256(abi.encode(l))) % numIds) + 1;
            uint256 currentIdTotalFunding = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId).totalFunding; // get existing funding value

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.Sponsorship(sponsor, uint96(pseudoRandomIdeaId), IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomSponsorValue), false));
            
            vm.prank(sponsor);
            ideaTokenHub.sponsorIdea{value: pseudoRandomSponsorValue}(pseudoRandomIdeaId);

            assertEq(ideaTokenHub.balanceOf(sponsor, pseudoRandomIdeaId), pseudoRandomSponsorValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId);
            // check that `IdeaInfo.totalFunding` increased by `pseudoRandomSponsorValue`, ergo `currentTotalFunding`
            currentIdTotalFunding += pseudoRandomSponsorValue;
            assertEq(newInfo.totalFunding, currentIdTotalFunding);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);

            eoa = !eoa;
        }

        // get values for assertions
        (uint32 prevCurrentRound, uint32 prevStartBlock) = ideaTokenHub.currentRoundInfo();
        
        // fast forward to round completion block and finalize
        vm.roll(block.number + roundLength);
        (IPropLot.Delegation[] memory delegations, uint96[] memory winningIdeaIds, uint256[] memory nounsProposalIds) = ideaTokenHub.finalizeRound();
        
        (uint32 postCurrentRound, uint32 postStartBlock) = ideaTokenHub.currentRoundInfo();
        assertEq(postCurrentRound, prevCurrentRound + 1);
        assertTrue(postStartBlock > prevStartBlock);

        uint256 endMinRequiredVotes = propLot.getCurrentMinRequiredVotes();
        if (delegations.length == 0) {
            assertTrue(startMinRequiredVotes != endMinRequiredVotes);
            // assert no proposals were made
            assertEq(nounsProposalIds.length, 0);
        } else {
            // assert yield ledger was written properly
            uint256 winnersTotalFunding;
            for (uint256 n; n < winningIdeaIds.length; ++n) {
                uint256 currentWinnerTotalFunding = ideaTokenHub.getIdeaInfo(winningIdeaIds[n]).totalFunding;
                winnersTotalFunding += currentWinnerTotalFunding;
            }

            for (uint256 o; o < delegations.length; ++o) {
                address currentDelegator = delegations[o].delegator;
                uint256 returnedYield = ideaTokenHub.getClaimableYield(currentDelegator);
                assertTrue(returnedYield != 0);
                
                uint256 denominator = 10_000 * endMinRequiredVotes / delegations[o].votingPower;
                uint256 currentYield = winnersTotalFunding / delegations.length / denominator / 10_000;
                assertEq(returnedYield, currentYield);
            }
        }
    }

    // function test_finalizeAuctionNoEligibleProposers()
    
    function test_revertFinalizeAuctionIncompleteRound(uint8 numCreators, uint8 numSponsors, uint8 numSupplementaryDelegations, uint8 numFullDelegations) public {
        vm.assume(numSponsors != 0);
        vm.assume(numCreators != 0);
        vm.assume(numFullDelegations != 0 || numSupplementaryDelegations > 1);

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // perform supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            // mint `minRequiredVotes / 2` to new nounder and delegate
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            uint256 returnedSupplementaryBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
            assertEq(returnedSupplementaryBalance, amt);
            
            uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, true);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentSupplementaryNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentSupplementaryNounder, delegateId, amt);
            vm.stopPrank();

            eoa = !eoa;
        }

        // perform full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes; // amount to mint

            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);
            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, false);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentFullNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentFullNounder, delegateId, amt);
            vm.stopPrank();

            eoa = !eoa;
        }

        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        
        // create ideas
        for (uint256 k; k < numCreators; ++k) {
            uint256 currentIdeaId = startId + k;
            assertEq(ideaTokenHub.getNextIdeaId(), currentIdeaId);
            // targets 10e15 order; not truly random but appropriate for testing
            uint256 pseudoRandomIdeaValue = uint256(keccak256(abi.encode(k))) / 10e15;

            // alternate between simulating EOA and smart contract wallets
            uint256 collisionOffset = k + numSupplementaryDelegations + numFullDelegations; // prevent collisions
            address nounder = eoa ? _createNounderEOA(collisionOffset) : _createNounderSmartAccount(collisionOffset);
            vm.deal(nounder, pseudoRandomIdeaValue);

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.IdeaCreated(IPropLot.Proposal(txs, description), nounder, uint96(currentIdeaId), IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomIdeaValue), true));
            
            vm.prank(nounder);
            ideaTokenHub.createIdea{value: pseudoRandomIdeaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), pseudoRandomIdeaValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, pseudoRandomIdeaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);

            eoa = !eoa;
        }

        // sponsor ideas
        for (uint256 l; l < numSponsors; ++l) {
            assertEq(ideaTokenHub.getNextIdeaId(), uint256(numCreators) + 1);
            // targets 10e16 order; not truly random but appropriate for testing
            uint256 pseudoRandomSponsorValue = uint256(keccak256(abi.encode(l << 2))) / 10e15;

            // alternate between simulating EOA and smart contract wallets
            uint256 collisionOffset = l + numCreators + numSupplementaryDelegations + numFullDelegations;
            address sponsor = eoa ? _createNounderEOA(collisionOffset) : _createNounderSmartAccount(collisionOffset);
            vm.deal(sponsor, pseudoRandomSponsorValue);

            // reduce an entropic hash to the `[0:nextIdeaId]` range via modulo
            uint256 numIds = ideaTokenHub.getNextIdeaId() - 1;
            // add 1 since modulo produces one less than desired range, incl 0
            uint256 pseudoRandomIdeaId = (uint256(keccak256(abi.encode(l))) % numIds) + 1;
            uint256 currentIdTotalFunding = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId).totalFunding; // get existing funding value

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.Sponsorship(sponsor, uint96(pseudoRandomIdeaId), IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomSponsorValue), false));
            
            vm.prank(sponsor);
            ideaTokenHub.sponsorIdea{value: pseudoRandomSponsorValue}(pseudoRandomIdeaId);

            assertEq(ideaTokenHub.balanceOf(sponsor, pseudoRandomIdeaId), pseudoRandomSponsorValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId);
            // check that `IdeaInfo.totalFunding` increased by `pseudoRandomSponsorValue`, ergo `currentTotalFunding`
            currentIdTotalFunding += pseudoRandomSponsorValue;
            assertEq(newInfo.totalFunding, currentIdTotalFunding);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposal.ideaTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposal.ideaTxs.values.length, txs.values.length);
            assertEq(newInfo.proposal.ideaTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposal.ideaTxs.calldatas.length, txs.calldatas.length);
            assertEq(newInfo.proposal.description, description);

            eoa = !eoa;
        }

        // ensure round cannot be finalized until `roundLength` has passed
        bytes memory err = abi.encodeWithSelector(IIdeaTokenHub.RoundIncomplete.selector);
        vm.expectRevert(err);
        ideaTokenHub.finalizeRound();
    }


    // function test_invariantGetOrderedEligibleIdeaIds() {
    //             //todo move this assertion loop into an invariant test as it only asserts the invariant that `winningIds` is indeed ordered properly
    //             uint256 prevBal;
    //             for (uint256 z = winningIds.length; z > 0; --z) {
    //                 uint256 index = z - 1;
    //                 uint96 currentWinningId = winningIds[index];
    //                 assert(ideaInfos[currentWinningId].totalFunding >= prevBal);
        
    //                 prevBal = ideaInfos[currentWinningId].totalFunding;
    //             }
    // }
    // function test_claim()
    // function test_revertTransfer()
    // function test_revertBurn()
    // function test_uri
}