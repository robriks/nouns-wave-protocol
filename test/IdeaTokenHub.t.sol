// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IIdeaTokenHub} from "src/interfaces/IIdeaTokenHub.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {WaveTest} from "test/Wave.t.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";
import {NounsEnvSetup} from "test/helpers/NounsEnvSetup.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

/// @dev This IdeaTokenHub test suite inherits from the Nouns governance setup contract to mimic the onchain environment
contract IdeaTokenHubTest is NounsEnvSetup, TestUtils {
    WaveHarness waveCoreImpl;
    WaveHarness waveCore;
    IdeaTokenHub ideaTokenHubImpl;
    IdeaTokenHub ideaTokenHub;

    uint256 waveLength;
    uint256 minSponsorshipAmount;
    uint256 decimals;
    string uri;
    ProposalTxs txs;
    string description;
    // singular proposal stored for easier referencing against `IdeaInfo` struct member
    IWave.Proposal proposal;
    IdeaTokenHub.WaveInfo firstWaveInfo; // only used for sanity checks

    function setUp() public {
        // establish clone of onchain Nouns governance environment
        super.setUpNounsGovernance();

        // setup Wave contracts
        waveLength = 100800;
        minSponsorshipAmount = 0.00077 ether;
        decimals = 18;
        uri = "someURI";
        // roll to block number of at least `waveLength` to prevent underflow within current Wave `startBlock`
        vm.roll(waveLength);

        ideaTokenHubImpl = new IdeaTokenHub();
        ideaTokenHub = IdeaTokenHub(address(new ERC1967Proxy(address(ideaTokenHubImpl), "")));
        waveCoreImpl = new WaveHarness();
        bytes memory initData = abi.encodeWithSelector(
            IWave.initialize.selector,
            address(ideaTokenHub),
            address(nounsGovernorProxy),
            address(nounsTokenHarness),
            minSponsorshipAmount,
            waveLength,
            uri
        );
        waveCore = WaveHarness(address(new ERC1967Proxy(address(waveCoreImpl), initData)));

        // setup mock proposal
        txs.targets.push(address(0x0));
        txs.values.push(1);
        txs.signatures.push("");
        txs.calldatas.push("");
        description = "test";

        // provide funds for `txs` value
        vm.deal(address(this), 1 ether);

        // balances to roughly mirror mainnet
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsForkEscrow_), 265);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(nounsDAOSafe_, 30);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71, 308);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsTokenHarness), 25);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(0x1), 370); // ~rest of missing supply to dummy address

        // continue with IdeaTokenHub configuration
        firstWaveInfo.startBlock = uint32(block.number);
        proposal = IWave.Proposal(txs, description);
    }

    function test_setUp() public {
        // sanity checks
        assertEq(ideaTokenHub.waveLength(), waveLength);
        assertEq(ideaTokenHub.minSponsorshipAmount(), minSponsorshipAmount);
        assertEq(ideaTokenHub.decimals(), decimals);

        // no IdeaIds have yet been created (IDs start at 1)
        uint256 startId = ideaTokenHub.getNextIdeaId();
        assertEq(startId, 1);
        (uint256 currentWaveId, IIdeaTokenHub.WaveInfo memory currentWaveInfo) = ideaTokenHub.getCurrentWaveInfo();
        assertTrue(currentWaveId == 0); // first Wave ID begins at 0
        assertEq(currentWaveInfo.startBlock, firstWaveInfo.startBlock);
        assertEq(currentWaveInfo.endBlock, 0); // first Wave's `endBlock` is not known at this point

        bytes memory err = abi.encodeWithSelector(IIdeaTokenHub.NonexistentIdeaId.selector, startId);
        vm.expectRevert(err);
        ideaTokenHub.getIdeaInfo(startId);
    }

    function test_createIdeaEOA(uint64 ideaValue, uint8 numCreators) public {
        vm.assume(numCreators != 0);
        ideaValue = uint64(bound(ideaValue, minSponsorshipAmount, type(uint64).max));

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
            emit IIdeaTokenHub.IdeaCreated(
                IWave.Proposal(txs, description),
                nounder,
                uint96(currentIdeaId),
                IIdeaTokenHub.SponsorshipParams(ideaValue, true)
            );

            vm.prank(nounder);
            ideaTokenHub.createIdea{value: ideaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), ideaValue);
        }

        IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(startId);
        assertEq(newInfo.totalFunding, ideaValue);
        assertEq(newInfo.blockCreated, uint32(block.number));
        assertFalse(newInfo.isProposed);
        assertEq(newInfo.proposalTxs.targets.length, txs.targets.length);
        assertEq(newInfo.proposalTxs.values.length, txs.values.length);
        assertEq(newInfo.proposalTxs.signatures.length, txs.signatures.length);
        assertEq(newInfo.proposalTxs.calldatas.length, txs.calldatas.length);
    }

    function test_createIdeaSmartAccount(uint64 ideaValue, uint8 numCreators) public {
        vm.assume(numCreators != 0);
        ideaValue = uint64(bound(ideaValue, minSponsorshipAmount, type(uint64).max));

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
            emit IIdeaTokenHub.IdeaCreated(
                IWave.Proposal(txs, description),
                nounder,
                uint96(currentIdeaId),
                IIdeaTokenHub.SponsorshipParams(ideaValue, true)
            );

            vm.prank(nounder);
            ideaTokenHub.createIdea{value: ideaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), ideaValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, ideaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposalTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposalTxs.values.length, txs.values.length);
            assertEq(newInfo.proposalTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposalTxs.calldatas.length, txs.calldatas.length);
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
            emit IIdeaTokenHub.IdeaCreated(
                IWave.Proposal(txs, description),
                nounder,
                uint96(currentIdeaId),
                IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomIdeaValue), true)
            );

            vm.prank(nounder);
            ideaTokenHub.createIdea{value: pseudoRandomIdeaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), pseudoRandomIdeaValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, pseudoRandomIdeaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposalTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposalTxs.values.length, txs.values.length);
            assertEq(newInfo.proposalTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposalTxs.calldatas.length, txs.calldatas.length);

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
            uint96 pseudoRandomIdeaId = uint96((uint256(keccak256(abi.encode(l))) % numIds)) + 1;
            uint256 currentIdTotalFunding = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId).totalFunding; // get existing funding value

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.Sponsorship(
                sponsor,
                uint96(pseudoRandomIdeaId),
                IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomSponsorValue), false),
                ""
            );

            vm.prank(sponsor);
            ideaTokenHub.sponsorIdea{value: pseudoRandomSponsorValue}(pseudoRandomIdeaId);

            assertEq(ideaTokenHub.balanceOf(sponsor, pseudoRandomIdeaId), pseudoRandomSponsorValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId);
            // check that `IdeaInfo.totalFunding` increased by `pseudoRandomSponsorValue`, ergo `currentTotalFunding`
            currentIdTotalFunding += pseudoRandomSponsorValue;
            assertEq(newInfo.totalFunding, currentIdTotalFunding);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposalTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposalTxs.values.length, txs.values.length);
            assertEq(newInfo.proposalTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposalTxs.calldatas.length, txs.calldatas.length);

            eoa = !eoa;
        }
    }

    function test_finalizeWave(
        uint8 numSupplementaryDelegations,
        uint8 numFullDelegations,
        uint8 numCreators,
        uint8 numSponsors
    ) public {
        vm.assume(numSponsors != 0);
        vm.assume(numCreators != 0);
        vm.assume(numFullDelegations != 0 || numSupplementaryDelegations > 1);

        uint256 startMinRequiredVotes = waveCore.getCurrentMinRequiredVotes(); // stored for assertions

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // perform supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            // mint `minRequiredVotes / 2` to new nounder and delegate
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);

            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            uint256 returnedSupplementaryBalance =
                NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
            assertEq(returnedSupplementaryBalance, amt);

            uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, true);
            address delegate = waveCore.getDelegateAddress(delegateId);

            vm.startPrank(currentSupplementaryNounder);
            nounsTokenHarness.delegate(delegate);
            waveCore.registerDelegation(currentSupplementaryNounder, delegateId);
            vm.stopPrank();

            // simulate time passing
            vm.roll(block.number + 200);
            eoa = !eoa;
        }

        // perform full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);

            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes; // amount to mint

            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);
            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, false);
            address delegate = waveCore.getDelegateAddress(delegateId);

            vm.startPrank(currentFullNounder);
            nounsTokenHarness.delegate(delegate);
            waveCore.registerDelegation(currentFullNounder, delegateId);
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

            vm.startPrank(nounder);
            try ideaTokenHub.createIdea{value: pseudoRandomIdeaValue}(txs, description) returns (uint96 newIdeaId) {
                assertEq(newIdeaId, uint96(currentIdeaId));
            } catch {
                // wave must first be finalized
                (,, uint96[] memory winners) = ideaTokenHub.getWinningIdeaIds();
                string[] memory descs = new string[](winners.length);
                for (uint256 d; d < winners.length; ++d) {
                    descs[d] = description;
                }
                ideaTokenHub.finalizeWave(winners, descs);

                // then resubmit call to `createIdea()`
                ideaTokenHub.createIdea{value: pseudoRandomIdeaValue}(txs, description);
            }
            vm.stopPrank();

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), pseudoRandomIdeaValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, pseudoRandomIdeaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposalTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposalTxs.values.length, txs.values.length);
            assertEq(newInfo.proposalTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposalTxs.calldatas.length, txs.calldatas.length);

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
            uint96 pseudoRandomIdeaId = uint96(uint256(keccak256(abi.encode(l))) % numIds) + 1;
            uint256 currentIdTotalFunding = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId).totalFunding; // get existing funding value

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.Sponsorship(
                sponsor,
                uint96(pseudoRandomIdeaId),
                IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomSponsorValue), false),
                ""
            );

            vm.prank(sponsor);
            ideaTokenHub.sponsorIdea{value: pseudoRandomSponsorValue}(pseudoRandomIdeaId);

            assertEq(ideaTokenHub.balanceOf(sponsor, pseudoRandomIdeaId), pseudoRandomSponsorValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId);
            // check that `IdeaInfo.totalFunding` increased by `pseudoRandomSponsorValue`, ergo `currentTotalFunding`
            currentIdTotalFunding += pseudoRandomSponsorValue;
            assertEq(newInfo.totalFunding, currentIdTotalFunding);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposalTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposalTxs.values.length, txs.values.length);
            assertEq(newInfo.proposalTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposalTxs.calldatas.length, txs.calldatas.length);

            eoa = !eoa;
        }

        // get values for assertions
        (uint256 previousWaveId, IIdeaTokenHub.WaveInfo memory preWaveInfo) = ideaTokenHub.getCurrentWaveInfo();

        // fast forward to wave completion block and finalize
        vm.roll(block.number + waveLength);
        uint96[] memory winningIds;
        (,, winningIds) = ideaTokenHub.getWinningIdeaIds();
        string[] memory descriptions = new string[](winningIds.length);
        for (uint256 m; m < winningIds.length; ++m) {
            descriptions[m] = description;
        }
        (IWave.Delegation[] memory delegations, uint256[] memory nounsProposalIds) =
            ideaTokenHub.finalizeWave(winningIds, descriptions);

        (uint256 currentWaveId, IIdeaTokenHub.WaveInfo memory postWaveInfo) = ideaTokenHub.getCurrentWaveInfo();
        assertTrue(currentWaveId == previousWaveId + 1);
        assertTrue(postWaveInfo.startBlock > preWaveInfo.startBlock);

        // `preWaveInfo.endBlock` is assigned by `finalizeWave()` so it was still 0 when first fetched. Thus, refetch
        IIdeaTokenHub.WaveInfo memory finalizedPreviousWaveInfo = ideaTokenHub.getWaveInfo(previousWaveId);
        assertTrue(postWaveInfo.startBlock == finalizedPreviousWaveInfo.endBlock);

        uint256 endMinRequiredVotes = waveCore.getCurrentMinRequiredVotes();
        if (delegations.length == 0) {
            assertTrue(startMinRequiredVotes != endMinRequiredVotes);
            // assert no proposals were made
            assertEq(nounsProposalIds.length, 0);
        } else {
            // assert yield ledger was written properly
            uint256 winnersTotalFunding;
            for (uint256 n; n < winningIds.length; ++n) {
                uint256 currentWinnerTotalFunding = ideaTokenHub.getIdeaInfo(winningIds[n]).totalFunding;
                winnersTotalFunding += currentWinnerTotalFunding;
            }

            for (uint256 o; o < delegations.length; ++o) {
                address currentDelegator = delegations[o].delegator;
                uint256 returnedYield = ideaTokenHub.getClaimableYield(currentDelegator);
                assertTrue(returnedYield != 0);

                uint256 denominator = 10_000 * endMinRequiredVotes / delegations[o].votingPower;
                uint256 currentYield = winnersTotalFunding / delegations.length / denominator / 10_000;
                assertEq(returnedYield, currentYield);

                vm.prank(currentDelegator);
                ideaTokenHub.claim();
            }
        }
    }

    function test_revertfinalizeWaveIncompleteWave(
        uint8 numCreators,
        uint8 numSponsors,
        uint8 numSupplementaryDelegations,
        uint8 numFullDelegations
    ) public {
        vm.assume(numSponsors != 0);
        vm.assume(numCreators != 0);
        vm.assume(numFullDelegations != 0 || numSupplementaryDelegations > 1);

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // perform supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            // mint `minRequiredVotes / 2` to new nounder and delegate
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);
            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            uint256 returnedSupplementaryBalance =
                NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
            assertEq(returnedSupplementaryBalance, amt);

            uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, true);
            address delegate = waveCore.getDelegateAddress(delegateId);

            vm.startPrank(currentSupplementaryNounder);
            nounsTokenHarness.delegate(delegate);
            waveCore.registerDelegation(currentSupplementaryNounder, delegateId);
            vm.stopPrank();

            eoa = !eoa;
        }

        // perform full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes; // amount to mint

            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);
            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, false);
            address delegate = waveCore.getDelegateAddress(delegateId);

            vm.startPrank(currentFullNounder);
            nounsTokenHarness.delegate(delegate);
            waveCore.registerDelegation(currentFullNounder, delegateId);
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
            emit IIdeaTokenHub.IdeaCreated(
                IWave.Proposal(txs, description),
                nounder,
                uint96(currentIdeaId),
                IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomIdeaValue), true)
            );

            vm.prank(nounder);
            ideaTokenHub.createIdea{value: pseudoRandomIdeaValue}(txs, description);

            assertEq(ideaTokenHub.balanceOf(nounder, currentIdeaId), pseudoRandomIdeaValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(currentIdeaId);
            assertEq(newInfo.totalFunding, pseudoRandomIdeaValue);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposalTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposalTxs.values.length, txs.values.length);
            assertEq(newInfo.proposalTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposalTxs.calldatas.length, txs.calldatas.length);

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
            uint96 pseudoRandomIdeaId = uint96((uint256(keccak256(abi.encode(l))) % numIds)) + 1;
            uint256 currentIdTotalFunding = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId).totalFunding; // get existing funding value

            vm.expectEmit(true, true, true, false);
            emit IIdeaTokenHub.Sponsorship(
                sponsor,
                uint96(pseudoRandomIdeaId),
                IIdeaTokenHub.SponsorshipParams(uint216(pseudoRandomSponsorValue), false),
                ""
            );

            vm.prank(sponsor);
            ideaTokenHub.sponsorIdea{value: pseudoRandomSponsorValue}(pseudoRandomIdeaId);

            assertEq(ideaTokenHub.balanceOf(sponsor, pseudoRandomIdeaId), pseudoRandomSponsorValue);

            IIdeaTokenHub.IdeaInfo memory newInfo = ideaTokenHub.getIdeaInfo(pseudoRandomIdeaId);
            // check that `IdeaInfo.totalFunding` increased by `pseudoRandomSponsorValue`, ergo `currentTotalFunding`
            currentIdTotalFunding += pseudoRandomSponsorValue;
            assertEq(newInfo.totalFunding, currentIdTotalFunding);
            assertEq(newInfo.blockCreated, uint32(block.number));
            assertFalse(newInfo.isProposed);
            assertEq(newInfo.proposalTxs.targets.length, txs.targets.length);
            assertEq(newInfo.proposalTxs.values.length, txs.values.length);
            assertEq(newInfo.proposalTxs.signatures.length, txs.signatures.length);
            assertEq(newInfo.proposalTxs.calldatas.length, txs.calldatas.length);

            eoa = !eoa;
        }

        uint96[] memory winningIds;
        (,, winningIds) = ideaTokenHub.getWinningIdeaIds();
        string[] memory descriptions = new string[](winningIds.length);
        for (uint256 m; m < winningIds.length; ++m) {
            descriptions[m] = description;
        }
        // ensure wave cannot be finalized until `waveLength` has passed
        bytes memory err = abi.encodeWithSelector(IIdeaTokenHub.WaveIncomplete.selector);
        vm.expectRevert(err);
        ideaTokenHub.finalizeWave(winningIds, descriptions);
    }
}
