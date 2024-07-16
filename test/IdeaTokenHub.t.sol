// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {FontRegistry} from "FontRegistry/src/FontRegistry.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IIdeaTokenHub} from "src/interfaces/IIdeaTokenHub.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Renderer} from "src/SVG/Renderer.sol";
import {PolymathTextRegular} from "src/SVG/fonts/PolymathTextRegular.sol";
import {Font} from "test/svg/HotChainSVG.t.sol";
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
    FontRegistry fontRegistry;
    PolymathTextRegular polymathTextRegular;
    Renderer renderer;

    uint256 waveLength;
    uint256 minSponsorshipAmount;
    uint256 decimals;
    NounsDAOV3Proposals.ProposalTxs txs;
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
        // roll to block number of at least `waveLength` to prevent underflow within current Wave `startBlock`
        vm.roll(waveLength);
        
        // deploy and add font to registry
        fontRegistry = new FontRegistry();
        string memory root = vm.projectRoot();
        string memory fontPath = string.concat(root, "/test/helpers/font.json");
        string memory json = vm.readFile(fontPath);
        Font memory polyFont = abi.decode(vm.parseJson(json), (Font));
        string memory polyText = polyFont.data;
        polymathTextRegular = new PolymathTextRegular(polyText);
        fontRegistry.addFontToRegistry(address(polymathTextRegular));

        // deploy Wave infra
        renderer = new Renderer(address(fontRegistry), address(nounsDescriptor_), address(nounsRenderer_));
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
            address(renderer)
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
        (uint96 previousWaveId, IIdeaTokenHub.WaveInfo memory preWaveInfo) = ideaTokenHub.getCurrentWaveInfo();

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

        (uint96 currentWaveId, IIdeaTokenHub.WaveInfo memory postWaveInfo) = ideaTokenHub.getCurrentWaveInfo();
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

    function test_uri() public {
        // create ideaToken
        address nounder = _createNounderEOA(0);
        vm.deal(nounder, minSponsorshipAmount);

        vm.prank(nounder);
        ideaTokenHub.createIdea{value: minSponsorshipAmount}(txs, description);

        // check URI content
        string memory json = ideaTokenHub.uri(1);

        string memory correct = "data:application/json;base64,eyJuYW1lIjogIldhdmUgUHJvdG9jb2wgSWRlYVRva2VuIDEiLCJkZXNjcmlwdGlvbiI6ICJUb2tlbml6ZWQgaWRlYSBjb21wZXRpbmcgZm9yIHByb3Bvc2FsIHRvIE5vdW5zIGdvdmVybmFuY2UgdGhyb3VnaCBXYXZlIFByb3RvY29sLiBUbyB2aWV3IHRoZSBkZXNjcmlwdGlvbiBmb3IgYSBzcGVjaWZpYyBpZGVhLCBjb25zdWx0IHRoZSBXYXZlIFByb3RvY29sIFVJLiIsImV4dGVybmFsX3VybCI6ICJodHRwczovL3dhdmUtbW9ub3JlcG8tYXBwLnZlcmNlbC5hcHAiLCJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMG5Namd3SnlCb1pXbG5hSFE5SnpJNE1DY2dkbWxsZDBKdmVEMG5NQ0F3SURJNE1DQXlPREFuSUhodGJHNXpQU2RvZEhSd09pOHZkM2QzTG5jekxtOXlaeTh5TURBd0wzTjJaeWNnYzJoaGNHVXRjbVZ1WkdWeWFXNW5QU2RqY21semNFVmtaMlZ6SnlCNGJXeHVjenA0YkdsdWF6MG5hSFIwY0RvdkwzZDNkeTUzTXk1dmNtY3ZNVGs1T1M5NGJHbHVheWMrUEhOMGVXeGxJSFI1Y0dVOUozUmxlSFF2WTNOekp6NUFabTl1ZEMxbVlXTmxJSHRtYjI1MExXWmhiV2xzZVRvZ0oxQnZiSGxVWlhoMEp6dG1iMjUwTFhOMGVXeGxPaUJ1YjNKdFlXdzdjM0pqT25WeWJDaGtZWFJoT21admJuUXZiM1JtTzJOb1lYSnpaWFE5ZFhSbUxUZzdZbUZ6WlRZMExGUXhVbFZVZDBGTFFVbEJRVUYzUVdkUk1GcEhTVUpGUzNoeFFVRkJRV2hWUVVGQldGUnJaRVZTVlZsQlJXZEJNa0ZCUVdad1FVRkJRVUphVUZWNU9IbGhSR3hzWVVGQlFVRlNRVUZCUVVKbldUSXhhR05CUmpoQmJYZEJRVUZtVVVGQlFVRmFSMmhzV1ZkUmJrNVFlR3RCUVVGQmNrRkJRVUZFV205aFIxWm9RalJuUkVaUlFVRkJUMUZCUVVGQmEyRkhNVEJsU2s1clJIQnpRVUZDS3poQlFVRkNSRWN4YUdWSVFVRlJNVUZCUVVGQlFrTkJRVUZCUVZwMVdWY3hiRzVMV0VwWVowRkJRVmhCUVVGQldtVmpSemw2WkZBNU0wRkVkMEZCUVdjd1FVRkJRVWxCUVVKQlFVRkJRVkp0WVRkUEswRnhNVGhRVUZCVlFVRjNVRzlCUVVGQlFVOUpWRFJ1WjBGQlFVRkJOR3RQT1doUlFVTXZkemhFZUVGTVlrRkJRVUZDWjBGRFFVRkJRVUZCUVVGQlFVVkJRVUZRUVM5MVowRkJRVkJ1UVVGSlFVRm5VRVZCUVVWQlFVRkJRVUZCUVVGQlFVRkJRVUZCUVVGQlFrUkJRVUpSUVVGQ1JFRkJRVUZDUVVsNlFWcEJRVUpSUVVsQmIyOURWMEZCUVVGRmMwTnBaMHBaUVVGQlFsaG5RVGhCVldOQlFVRkpURUpSVVVSQ1VVbEhRWGROUVVGQlFVUkJRVUZCUVVGQlFVRkJRVUZCUVVGQlZEQm9UMVIzU0VGQlEwRkJiMEZRUVM5MVowRkJRVkl3UVdVd1FVRkJRVUpCUVVGQlFVRklVMEZ4YTBGQlFVRm5RVUZCUVVGQlFWSkJUa2xCUVhkQlFrSkJhMEZCUVVJNFFVRkJRVUYzUVVKQ1FXdEJRVkZCYTBGSWQwRkJkMEZDUWtGclFVRm5RVTlCUzBGQlFYZEJRa0pCYTBGQmQwSlBRVXMwUVVGM1FVSkNRV3RCUWtGQk1FRlFkMEZCZDBGQ1FrRnJRVUpSUVdGQlZFRkJRWGRCUWtKQmEwRkNaMEYzUVZWdlFVRjNRVUpDUVd0QlFuZENiVUZZYjBGQmQwRkNRa0ZyUVVOQlFXdEJaVUZCUVhkQlFrSkJhMEZEVVVGclFXVkJRVUYzUVVKQ1FXdEJRM2RCYlVGblVVRkJkMEZDUWtGclFVUkJRVzFCWjFGQlFYZEJRa0pCYTBGRVVVeDFRV2x2UVVGM1FVSkNRV3RCUkdkQ1RVSlNaMEZCZDBGQ1FrRnJRVVZCUVd0QlNIZEJRWGRCUWtKQmEwRkZVVUZQUVV0QlFVRjNRVUpDUVd0QlJYZEJiMEpYVVVGUmQwSjJRVWhCUVdWUlFubEJSMnRCV25kQ2IwRklVVUZKUVVOd1FVTkJRVTFuUVhkQlJFbEJUa0ZCWjBGRk9FRlRRVUZuUVVjMFFXSjNRV2RCUmxGQlpWRkNkMEZIVlVGSlFVSkVRVWM0UVdKUlFuZEJSMFZCWW1kQ05VRkRkMEZKUVVKTlFVVjNRVkYzUVhWQlEwRkJVVkZDYzBGSGQwRkpRVUo1UVVkclFWcDNRbTlCU0ZGQlkzZEJaMEZJU1VGYVVVSjZRVWRWUVdOblFqSkJSMVZCV2tGQmRVRkdRVUZpZDBKelFVaHJRV0pSUW1oQlNGRkJZVUZCWjBGR1VVRmFVVUkwUVVoUlFVbEJRa1ZCUjFWQllsRkNka0ZHU1VGYVVVSnVRVWhWUVdKQlFtaEJTRWxCVkhkQ1NVRkZORUZVZDBFMlFVTkJRVlZCUW5aQlIzZEJaVkZDZEVGSFJVRmtRVUp2UVVOQlFWWkJRbXhCU0dkQlpFRkJaMEZGVVVGYVVVSjBRVWM0UVVsQlFsTkJSMVZCV25kQ01VRkhkMEZaVVVKNVFVUnZRVWxCUVhoQlF6UkJUVkZCZDBGRVFVRlZRVUoyUVVkM1FXVlJRblJCUjBWQlpFRkNiMEZEUVVGV1FVSnNRVWhuUVdSQlFXZEJSVkZCV2xGQ2RFRkhPRUZKUVVKVFFVZFZRVnAzUWpGQlIzZEJXVkZDZVVGR1dVRmFVVUo1UVVoTlFXRlJRblpCUnpSQlNVRkJlRUZETkVGTlVVRjNRVVJCUVZWQlFuWkJSM2RCWlZGQ2RFRkhSVUZrUVVKdlFVWlJRVnBSUWpSQlNGRkJVa0ZDYkVGSE1FRmlkMEYwUVVaSlFWcFJRbTVCU0ZWQllrRkNhRUZJU1VGVlFVSjJRVWQzUVdWUlFuUkJSMFZCWkVGQ2IwRkRRVUZoVVVKNlFVTkJRVmxSUVdkQlNGRkJZMmRDYUVGSFVVRmFVVUowUVVkRlFXTm5RbkpCUTBGQlluZENiVUZEUVVGVWQwSkpRVU5CUVdKblFuWkJRMEZCVmtGQ05VRklRVUZhVVVGblFVVk5RV0ozUW5SQlNFRkJXVkZDZFVGSWEwRk1RVUZuUVVWM1FWUkJRa1JCUXpSQlZIZENTVUZEUVVGaVowSjJRVU5CUVZaQlFqVkJTRUZCV2xGQlowRkZUVUZpZDBKMFFVaEJRVmxSUW5WQlNHdEJZVUZDTUVGSVVVRmpRVUo2UVVSdlFVeDNRWFpCUnpoQllVRkNkVUZIT0VGa1FVSTFRVWhCUVZwUlFYVkJSMDFCWW5kQ1ZVRkhaMEZoVVVKNlFVTkJRVnBuUW5aQlJ6UkJaRUZCWjBGSVRVRmlkMEp0UVVoUlFXUjNRbWhCU0VsQldsRkJaMEZIYTBGamQwRm5RVWhCUVdOblFuWkJTRUZCV2xGQ2VVRklVVUZsVVVGblFVYzRRVnBuUVdkQlJUaEJVMEZCWjBGSE5FRmlkMEZuUVVaUlFXVlJRbmRCUjFWQlNVRkNSRUZIT0VGaVVVSjNRVWRGUVdKblFqVkJRM2RCU1VGQ1RVRkZkMEZSZDBGMVFVTkJRVkpCUW14QlJ6QkJZbmRCWjBGSFdVRmlkMEoxUVVoUlFXTjNRV2RCUnpCQldWRkNOVUZEUVVGWlowSnNRVU5CUVdSUlFucEJSMVZCV2tGQlowRkhXVUZpZDBKNVFVTkJRV1JCUW14QlNFMUJaRUZDY0VGSE5FRmFkMEZuUVVkRlFXSm5RbXRCUTBGQldsRkNORUZJUVVGYVVVSjVRVWRyUVdKUlFteEJSelJCWkVGQ2NFRkhORUZhZDBGblFVaEJRV1JSUW5sQlNFRkJZbmRDZWtGSFZVRmpkMEZuUVVjNFFXSm5Rbk5CU0d0QlRHZEJaMEZHVlVGamQwSnNRVU5CUVdGUlFuVkJRMEZCWTNkQ01FRklWVUZhUVVKc1FVYzBRV1JCUVdkQlNHTkJZbmRDZVVGSGMwRkpRVUp3UVVoTlFVbEJRbmRCUjFWQlkyZENkRUZIYTBGa1FVSXdRVWRWUVZwQlFYVkJRMEZCVVdkQ05VRkRRVUZhUVVKMlFVaGpRV0puUW5OQlJ6aEJXVkZDYTBGSGEwRmlaMEp1UVVOQlFWbFJRblZCUjFGQlRIZENka0ZJU1VGSlFVSndRVWMwUVdOM1FqQkJSMFZCWWtGQ2MwRkhhMEZpWjBKdVFVTjNRVWxCUW1wQlJ6aEJZMEZDTlVGSGEwRmlaMEp1UVVOM1FVbEJRblpCU0VsQlNVRkNNVUZJVFVGaFVVSjFRVWRqUVVsQlFqQkJSMmRCWVZGQ2VrRkRRVUZTWjBKMlFVYzBRV1JCUVdkQlJrMUJZbmRDYlVGSVVVRmtkMEpvUVVoSlFWcFJRWE5CUTBGQlpWRkNka0ZJVlVGSlFVSm9RVWRqUVdOblFteEJSMVZCU1VGQ01FRkhaMEZhVVVGblFVaFJRVnBSUW5sQlJ6QkJZM2RCWjBGSE9FRmFaMEZuUVVjNFFXUlJRbmxCUTBGQlVsRkNkVUZIVVVGTVVVSldRVWhOUVZwUlFubEJRMEZCVkVGQ2NFRkhUVUZhVVVKMVFVaE5RVnBSUVdkQlJVVkJXbmRDZVVGSFZVRmFVVUowUVVkVlFXSm5RakJCUXpSQlNVRkNXa0ZIT0VGa1VVRm5RVWROUVZsUlFuVkJRMEZCV21kQ2NFRkhORUZhUVVGblFVZEZRVWxCUW1wQlJ6aEJZMEZDTlVGRFFVRmlkMEp0UVVOQlFXUkJRbTlCUjFWQlNVRkNRa0ZIWTBGalowSnNRVWRWUVdKUlFteEJSelJCWkVGQlowRkhPRUZpWjBKelFVZHJRV0puUW14QlEwRkJXVkZDTUVGRWIwRkpRVUp2UVVoUlFXUkJRbmRCU0UxQlQyZEJka0ZET0VGaWQwSnZRVWMwUVdKM1FqQkJTR3RCWTBGQ2JFRkRORUZaZDBKMlFVTTRRV0ZSUW5WQlIxbEJZbmRCZGtGSGQwRmhVVUpxUVVkVlFXSm5RbnBCUjFWQlkzZEJka0ZIVVVGYVVVSjBRVWM0UVV4blFtOUJTRkZCWkVGQ2QwRklUVUZQWjBGMlFVTTRRV0ozUW05QlJ6UkJZbmRDTUVGSWEwRmpRVUpzUVVNMFFWbDNRblpCUXpoQllWRkNkVUZIV1VGaWQwRjJRVWQzUVdGUlFtcEJSMVZCWW1kQ2VrRkhWVUZqZDBGMlFVZFJRVnBSUW5SQlJ6aEJVa0ZDYkVGSE1FRmlkMEZuUVVWWlFXSjNRblZCU0ZGQlkzZEJaMEZIUlVGalowSnNRVU5CUVZGM1FtOUJSMnRCWWtGQ2MwRkJRVUZCUVVGRFFVRkJRVUYzUVVGQlFsRkJRWGRCUWtGQlFVRkdRVUZGUVVaQlFVRkJRVkZCUWtGQlFYZEJRVUZEUVVGTVFVRjFRVVJyUVZkblFqWkJTMFF2TDNkQlFVRkRRVUZNUVVGMVFVUkJRVkZSUW1oQlMwUXZMeTh2YUVGQ1ZVRkZaMEZITHpoSUwzVXZLMmxCUVVWQlFVRkJRVUZCUVVGQlFVRkJRVUZCUVVGQlFVRkJRVTFCUVVGQlFVRkJSQzlrUVVFNFFVRkJRVUZCUVVGQlFVRkJRVUZCUVVGQlFVRkJRVUZCUVVGQlFrRkJVVU5CUVVWQ1FWSnNVV0l5ZURWaVYwWXdZVVpTYkdWSVVrVmFWekYyVEZaS2JGb3pWbk5aV0VsQlFWRkZRazFRWjJOQlVHZGtRV1puWlVSQlJEUklkMHcwU1VGUU5FZEJWRGRRWjNkRWVIZDNSV3BtZFVZcmJHbzFZbmRWWTBObWIxQnpVbmRSTWxKSlkwTm9RVkpCUVZsQ1FWRm5UbEZJZVZkeFNGWjFZVlJCZDFGVVFYaE1ha1YzVFVaQ2RtSkliSFJaV0ZKdlNVZHNla2xIUldka1NFcG9Xa2RXZEZsWVNuSkpSemx0U1VVNVNVbEhOWFpKUmxJMVkwZFZaMUV5T1hSalIwWjFaVk4zWjFSRmVFUk1hMDUyWTBoc2VXRlhaRzlrUTBGNVRVUkpNRWxGT1VsSlJ6VjJTVVpTTldOSFZXZFJNamwwWTBkR2RXVlRkMmRVUlhoRVRHbENRbUpIZDJkamJXeHVZVWhTZWtsSVNteGpNbFo1WkcxV2EweHNRblppU0d4MFdWaFNiMGxHVW14bFNGRm5Va2RXZEdKNVFsTmFWMlF4WWtkR2VWVkhPWE5sVnpGb1pFZG5aMVpIVmpSa1EwSkZXbGN4ZGtGSE1FTkJRVVZCUkhkQllrRkVSVUZPZDBFNVFVVlZRVk5uUWs5QlJrbEJWMEZDYlVGSE9FRmtaMEkzUVVsTlFXbG5RMkZCU3pCQmRWRkVhVUZRWjBKSFVVVndRVlJWUWxCM1JraEJWVEJDVjBGR2RFRllORUl3UVVodFFXWk5RaTluU1VoQmFFbERTMmRKTmtGclRVTlZaMHByUVc1dlEyaFJTMDlCY0ZWRGJsRkxiRUYwWjBSQ2QwMW1RWGxOUkZaQlRuVkJOVFJFZEVGUVQwRTVNRVEyZDFBelFrRk5SVVJSVVZkQ1FqUkZTbWRSZFVKSmMwVnRVVk0xUWsxTlJrSkJWVGxDVmtWR1YzZFdjRUphZDBaeFVWaEpRbVpCUjBSM1dUSkNhbk5IV1VGaFFrSndjMGQwUVdKT1FuVkpSemQzWTBOQ2VGVklTbmRqTUVJd1dVaFdkMlJ2UWpOTlNHZFJaVXhDTlc5SWNVRmxNa0k0VFVnd1FXWmtRaXRyU0RsUlowRkRRWE5KUm5abFMyZFNXRlozWVhKVGMwSXJWV2xuVlV4cGJYbExZbTEzWVRJdmFHMVBkMWxNYVdnek0wbHFTSG9yZVVRM1NVWlpaRFpqVFM5TGFXeFVVSGt3WmtNemJsa3JUV1paUXpONlZpdERkRE5ESzNkWEswVm9PRWhSV1V4a2RtczVaSGQxUWxGU01FeHZSR3RrUXpaQ01pdEhXak5ESzNkWE15OXBlVUp3TlhOdlYzbHBZbEZuVEdrNVpqTm1kR1l6WWpsalRHcExhVTF3WVdkaFF6bEpaemw0VVV4SEwzTmFVVk5NTjBsQmRsbDBSbGtyYkZJNFREazJSaXRHWldaUGRHUXlla2d3WlhOQ1dWbGtReTl6YXpSNVZETkhhRGMzU1ZCbE0wWmthVnAyVFVSWlIzZDJjMFoyWnpNeEwzWnFLMUJGTTBKbmRqTXJTR3RXT1hwWU0wRXZZMEU1TUdkbUswTTRNUzlEYTBncmVIQkhUMUJ6U2l0M2JFb3pMMk5hU0habmNFNVFkM1pDZW1ka1F6bHpWek5tWldKQ2IwVmtLelY2WkRrMk5FZzVkM2hoTVhaelIwaG5kak5wZUdKbk9UWmpSemswYmpSS2QxZFBUVkZtTjFkbWRtUXJNVzR6TTFGVmQybEJZak5wWm5kd1FsRjBZMGhrVEcxcWFDOXdlRVZWYlVwc1NrZE1VamhNTDBsWkx6a3ZPRWN2UTJZNE5IZFZUQ3N3YWpOQlpuTkJPWHBWWlVNellqTlJPV1kwVTFoalRFbDJjMllyZURCTU1uZE5kMGhWYTJSTlVqQjJTRkYyTTNJemQxWTVlV3BvTkM5alJqbDRhMmh6VUhOSmNtZzVPVWhSZEZWSVpDODRPRkpZTkhCbVkwMUNMMk12TmxsM1pFTXZaMjFsVWxnelZ5OWpWVGw1TnpOVFNtbExiVWx4V1VndmRsRlFMMlF6UW5aelRtVnFhMjhyZUhOaUszazRjemw0UkROTlVHTXhOVkJqVHpsNUwza3liRlYyYzBJdllYTlJXRE5EYkZnM1FXTTNOMGQ0ZGpkWlVITlhLM2x5TjFwMmRHVTVlSEkzVEM5a1owaDNjMGNyTjBnMVVrRldVMEpwYmpoVFVsZ3pSWFptVGpsM0x6ZDZVVlZNT1RaRU4yaFNXRE5JZFdacE9YbFpaa001VW1oa2RtZFBOREI2Vm1kSVkweHphR0kwY25SbU9FdEJXVXhVUlhJM1EzZzRObEF3VUZoQ2QzWm5RU3QzVnpNdlprNHJRVGMzZW1WRU5WQlVZamQxVUhkUE9UZG5NMEpuZFU5bU5GTk1aMUowU2xZeU1VMWllQ3REYWtGVlREbDNkMWN6VUdkbFoyZ3dUR1IyWjI5NVZUTlZSWFIyWWs4NU16Tm5kREJNYzJGVGJITkxOWGh3UjFwdVkxaEtiMXB4VW5oelFqaE1PUzlKUjJwS1UweHJjRkZoT1hsS1F6ZFFjMklyZUc5NlNTOXphVU40U3pZelVHVXhNMFIyWWxCa2EweHZTR0kwUzA1VU0ya3pZMHhxUzJsTmNIRnJZVU4zU0VJNWVFVkVPWGRuVEdrNVVETXhkRTlDYkZGelJISkNZbWRDZG1OYU9UQXZNMGN2ZEZCQ1pWZFJRblowUVRrekx6Tk9kbVI0UWxwQk5FSXZjMUlyTUVRM1JWQmtRVUpVUTBkQ2RtTXpLek5JTjFGbWRDOUNVWE5DTVRsNk0yZGtkMFE1Tm1RNFJtWmpUVEk1VkRORGVDOHpkRlJ5TjNSQlpFUllWbmhEVWtaNU5qQjROek4wUkhJM2RGRm1OME01ZEVNNWQzTmxRM2RIYnl0UlkwUnhRbUpwUW5SSU0xRjNXRE41VVdKUkt6Qk5SalY2T0dSRGQwNXVTRkZ6YzFwcWVGZEtRblkzUzJrM00wUXZZM2s1ZWt4dE9YaElNMHMwYjJZNFpIUlhTelk0WmpJM1JVWTVlRUpYSzNkSVRDdDRkMklyTVhvM1JpOXpkU3N5UlV3M1FtSXpXR2RpTTJObVkyTTVlRXd6WVM5a2NpdDRjak5GWm5SNVNDOTBaa0puYzBRNU1IbEdSbU5qUnpsNFVETXZVR05VS3k5M1JuaDNZak5QWm1oelFsUnJSeXQzWWpjM0wzTlJPU3M0UmxSQllqZEVkblp6SzNkcU16ZEJWVFJDWjNOM1NYWnphU3Q1VEcxSkwyTm5TRGxSUlV4c1RGZzNUek5FTVN0clRESkJWRGRNVTNvelJIWmplVGw2VkhBNWVFUXpURzl2WmpsNU4yNHJlRVEzVFhkelZrMVdhbE0zWlRJNU1DdGhUMGdyYmtWU1FYTjBWV1JJZHpkelZGTTJkVk1yVVhsdlprTjNTSE16ZDFCelJuUXZOVkJVWTBkREwzZENVUzlsUlVKMmRXUXZRbEZHUXpaTVZVWlVSbGt3ZFhwMWRsRnpVM1YwZWpOME9XODVNbEZ6UWpJNU1FUXllR0prUTNoTVlqSlVNMkpQT1RCTVpFRllOMEZMV0ZwUVFYUTNNbVptWm5wMlpIaGtkMGN2TTNabVZ6Tm5VRE4xTTNOV09YbHVjamxRWTJjNWVEaDVOUzl6VGxaSFFqSmhWMWxtYUZwWE1uUTNiUzl3U3pSYU5pOWpWMEphUVhCQ0wzTXJLelJKUmxjd2FITlRlbU5oSzNsRWNVa3ZZMjlJYjNwYVJsTmFVREoxV0dWNFRuSXpRVkJJUTFCVVkzWlVhalJ1U0hjM1dUa3pSRmc1TlM5WlFXTjJiRUY2TkdSRGQwaE1OVUZRTkVsSWExWTVlRE16UVdOMk0wVk5RV1pQTjBGR1ZYZ3pOMWxtWTFvcmVUTXpWM2c0VEdSMlpreDZabVEzTVVkVlpFTjNTSE16TDJWeE5FRlFjMFowTHpNeFdYZEhPVGt2TnpGUldETkJORGhIS3psVU0zaDNWM1ZDZG1OT016bEVNMEl2WTBwUFRrUTNSR2d2TjJobllqTm5WVWxXTVhJeGFGSkZSbUZZZWpobUsza3pNMlYzV1V3eWVHSmtPVFU0UnpKaVdFY3dPVXR6Vm5wWlpTczFMMk01TlRoSU1XRXZTekpPVTNKV2VsbGxLelV2WkRrMmIwZzVkM2hsTW5aelNGUkdhSEZUTW05bFoxRmlTMlZXY1hSU2VITk1PVFowSzBabGFsTjFkSFYzU0RJNFpDdDVVRzlKTDJObVNIZHpRamRPTHpSR1pWVkVVRkl3VEdWNE1GUjJVSE5pVEZJd1pVVTNhekpJVVRSRWRtaGliMEoyWkdnNU4yb3pXbEIxTkVKbGRWSkNkblZOT1N0Mk0yWm1abUZDV2tWM1FpOTBWaXMyVURkV2RtVnFRbE4xUmtKMlpDc3JPVzQzYVM5MmMwSlJkSGRJV1RaNGFreFBlRWQyWkRKUFVXTk1ORkZRYzBaMEx6TnhialJrS3pOelJ6TXZkbVpHWm1WVU9YbEZTRGMzVGxSUk1FNW5Wa05yWmtONVdXUkJaWHBtUVM5cFUwWjJZMFZxZDJJM09XWm1kamtyUkRNeVoxZFFTWGRtTnpCUWRrNUNabVpPVGk4d09UTXZabGxDZDNSTFNGSlBPRGswY1VKR1VrODJNV05IY1RCeVFXWnNTVzlHUlROeFMySkpjSFZpUW05VVprNXpURkkyZDBaV1dFcG1ZV3R6WWt4V1RGYzNkVGRFTVdWdVMzVkhjRmR2ZUM5UmNYZFlZbHByVXpaTWFIWTNTSGs0YWl0NVNVd3pVVTU0U0ZGMllrWjBNek50ZDJKWWREaDZXak0yZEZST2VEYzNiazR6TTNKUlpqTkVWblpYSzNkd1RsWnRkRXhoVWpaRGFrRlZUQ3RCVlZjNGJ6aEhLek5xTTJobVpIUTVNakJHYW5rd1NDc3lTRGRhZDFnMFlWUnVPV0ZPTXpOa1oyTk1PVGxwUWtabVkxb3haa3d6U1ZCalpWRXZXRGRGTUVKV1lUQlNia2cwUzAxQ1VYWk9jVXhFVEhwb2NqRlNjM28zUTBJM04zRjNZbVl2VUVsV09UUkVNMU4zWTB4a2RtcDRNWGRJTTJWMVFVUTVNMjlYTkZCcWVEa3lMMWd2U2pndk9USTRSME4zWWpOc0wydDVhSEJaUmk5SGRFRTVNRFJIZW5ObFRtcHpVV1pFZG5OdUswRlJSazVSWWpOVkwzaFpRbEYxU0hSU05sVnFVVlpJY2pjMWN6QlNkak5IWkZnd09YZzBUQzlMWm1jclZEQndRaTkxV0M5TFVEZHRMMmxxUWxOdlIwTjNWemQ2WVhKTk0yaHlNMGxEZWpBcmVXbzNTMU56YUVONE5rTnBVVmhRV2pGdGNsSkROR1JJZDNaWUt5OVVNMloyWm1NeEwzWmpPVEl2TXpZNVpqaFFkM1JKYjFWdGFUQm9ja3AyTnpkbWRrd3hORlppWTJWREwyTnFRblpqWlRSa1pqTkZMMk5PVG1SeU4wZG9PRXhrZG14dlpERTBaQ3RYWnpWQ1ozTklaMGszTjJRd1VVWlBkMll6VEhORlJrUjBjVFI1WkhKaGNteG5lVWhuZGpORGRGQTNRM1pqWWs5MmMySlFNRkJZUW1kME16WlFZMEpGYzNZelFtbHVaRVVyYW1KRE0ySTBTV1JoUm1RMlNqTkZkSFppVHprd1RDdDVXRGhEWm5Oc0swRnJSazV2YTBkRE1WSjJXVmMxVDBkNldsaDZUMkZHU0hkMldDdE1Vak55ZEdkVE1rOUVNMjg1T0V4cWJGbEdPU3RyUnpCM1ZEZExVVmxNWlRsdU0zUnpNek5VT1dWQ2JGSkpURGsyY0N0R1ptTm5OV1pRTTBsM2MxWTVlVzVuT0haalVqbDNkelpEZVc0M1QzWnpOMHRUYmpkUGVEaE1RVkZCUWtGQlFXbEhVVUpEUjFGQlVrTlJRVkJCUVVGT1FVRkhTRUZCUWtSQlowRkNRVUZWUVVOQlFVOUJSR05CVUdkQ1JrRkZPRUZpZDBJeFFVbEZRV2xCUTJ4QlMyOUJkSGRFVWtGUFRVRTNkMFZCUVZaelFsbEJSMlJCWVVsQ2NtZElVMEZuVVVORVowbGFRV2t3UTFSUlNtOUJia1ZEYUdkTFVrRnlORVJDWjAxTlFYaEJSRXBuVFhKQmVrVkVWa0ZPY0VFeldVUnhRVkE0UWtKalJVdEJVVE5DUkRCRlZXZFNaMEpIYjBWa1VWTlFRa3haUlRCblZXWkNWV05HWm1kWVJFSmpXVVl3ZDFoWFFtZ3dSMHAzV1RoQ2FpOHpZMnROU3lzdk1FOHphV2RrVlZJd1QzZHZkbGM1TkVSUk9UTmlWMFYxZW1ZNU9FaGhWV1ZGVkRsR1VVdEZMMmd3U0ZKUU1GVkJiMVFyVGpKNldWVjBVRnBGT0RGSWR6Y3pSM2xOWkZsNE1FODVkM000UTIxblpFUnVPSEpJVVVoek0zZE5iRWhSTlZkdlNHSXpkazVtTTJaa1kwSTNUamhFTjBKaVpqazNlak13WkdZM01HWmtPVGtyVEZndlJGbEhSSFprUm1WWFNXUkVkbU5tVDBGdlFqZE9MelJFYTFGa1JIWjJXRWwzY0dGSVVUYzNaMGxRV2xkcFdXUkZkbVJNTkVKUGQxUjNiMVJqU1ZaQlFsSlBkMmhhSzJkcFlVMWlSSE5QWjJKU01FOVhXWFpZSzFCR00wRmxlbVpCZWtsa1JIWm1TMnd6WVhCS2FEQlROMDR2TkhWUFFWUmxSbTlMUlRkb1UwTm9UalJsVWpCUE9Ya3JaRTVuYjFSWVEyOWtSVFozYmtOb1RtTkxRVzlQT1RFd2FraFJTRXcxWm1sRFNtZHZUMlEyUWpJNU5uSlVPVFZRV0VGbGVtWTVOakZ6U0ZFM00xaHBUV1JCWTNac0swbE1iRUV2WjIxbFVsaEpkMXB4YkhWU0t5dFJaMWh5YWxGWk5EbDNiMFo2T0hVeU5uWmpSRWQyWkdrcmVHNHpUR1owWmlzeEx6ZEhMM04wS3pKTU4xbDJZMklyZVhveldIZzFXRWhVZEhwUk1UbGFTQzl6Vmprd2MwWk1TV3RIT1hwaU4yVjNWalZoVjFOQ1dVSnpUM2R4UW10SVVUVXhaa2xqWkVVM1p6aElVbEEwZVUxVlJrVTNhbEJWTUU5cVVXaDJOMFo1TkRNcmQwUTNSSFUxYWpsM1ZtOUlPVTR4TURJNEswZHJaRlJXZWtwVlV6WllTVlpTTlU5VmQxVTRlV1ZPZGpKb2MwOVZOa0l4U0ZFM00wSnBWVXRCWlVocEswRlZjRU5uTjJkdFdHSTFVa2hqUW5GUWEwbEJMMlpQYUVKWVJrSjJaWGdyVlZGR1RYZGlOMlIyZVNzck0wdzBkbWRWZGtKbk56UkphMGxMUlhFM05rNVNUM2RVVVc5VU1GQmtlQ3RWVFVaTlVXSTNUaTk1YWtKU1QzY3JNR28wY0hkV1RrSjJkRW92UzFsR1JUbEVOMDlRYVdsQ1ZFbEhSSFpGYWtOblJ5c3JUelZ4U0ZFMU1VbDNiMEk1TkhablFYcFZaRVJ4YjNwRGFFdDBLMHhOVkRCRlNXUkZOMEpCUTJoUVVVNTRNRTlrUTJOa1JYSnlZemszWW1KUVpHdFViR2xCWkVVd05HaElVazl0U1VGdlZHeHBSVXRGTlZWcFEyYzFNR2RrVGs0MGEyeG5RMnR6UzJvM2JVeHdOelJoT1ROUk5VSjRUVFZuVURGdlVtZHZja3BCYjBKMWRIaFRTRkUxTUU5M2NqTnBNMlIxU0dac2IwOTJkREJDYlVOTVdqUTFhR0ZTTURKTVVXOUNkWFJ5TTI5NmMyUkVkblZHVDFGdlFqbDNlbU5CTDJOTlJuUjZORWgyWTIwd0wzTnRNM2RpVTNKTVJFdHRjSGxMYURWM1pXdGtSVVpyU0dRemFtNU5Za2xyVFdSRWJsVjRRMnd3WkVVNVdrRklVbEJQSzBjME9FSjRVRzFOWjI5VU1YTTVibGRoZEVaSEwzTmFVVVJ2WkRCNlZVdHhPVWQyU0RWVFMwSlhZVXRpYlZGaFRVWkNUVXd3YkdOeVlqVXhTR28xZDBKVU5uSXdiR0l6UVZKelZERlVNRXRFYlVKTVNGVmpTMFIyZGpkVFFYSTNLeTkwYkdSMmJFMW5lRE0zWldoWVpDdFZkelZDYUZCM1RVRnZUMGxoUWtwRFp6YzNLelpDTDBoUk56Tm5SRkZMUlhSMlpEa3lOMk01TWpka1JrSjNWSFpIV1dSVVJuaHVWREp6Wm1kdmQwWkZPWGR6U0ZSelIwUnRRMmRTZURCVWNrUlJaRVUzVVhORGFGQlZURUl3VkhwRWMwZEViREJyUTJkSE5qTlFaa0V5ZDAxcFNGRTFNRmhSY0ZaRGFGQnFWRUZ2VkRWVlNsUmhNRkp1U0RSTFRrSlNVRlpxUzNGTmNEWnZZVVU1VFRkQ2RtUTJMME5qVmtVcmJGcElVbEJVUzFab1JFMXZhMlZFYmxRM1dsaGlNMkl3TkV0RmNuSmpPVGRZWTFCa2ExUXhkbWN4S3pOdlZqTkJXVlI2ZG14TlQzZGpWRFZwUVV0Rk9XSlBXakZ0YzFKU2RqZEhhMFZwSzNndk4waGtTV2M1ZUZSV2QzRnlWSEo0SzFWcFVWZEpXVWwwYlZsQ2IxUXhabk52Tm14blpFcDVXbE5TVXpCbVJIWjFUMjlKVVdSRk9GRXJRMmhQVldwa1VVWkZPR2hHU0ZKUGIxUkNNRlJ3UkhOSFJIWjBUMlp6TnpNck9EUkNkazVtTTFKT1kwUk1aMjlQS3pWdFoyUjJaMlV3ZDBnelJFNTNSRkpvTUU5WFUxRmtWVUl3VDBrMFdIVlFXR0kwWWtoalUyNTJhR2RGTTBKWVEyaFBkMmhTTUU4NWVVdGhaSFpvYzJSM1IyVXJWbEpXU0ZFMGQwdFNNRUp5VUdoUVZIZ3dUMHRwYjB0QldqYzBXbWROY2tObk56ZE9WVFJrUlhBek5FcENVRkZ2YUdJMFNEbFFOMjkzV1ZSelF6aExSVGxCTDBOMVJqY3lkbWt2VTJkeVlVSlFjMVJTTDJOV09YbHlNMHRqTHpORkwyTlVPWGhNVUN0NFVEZExabk54VTFCelZpdDRUV1pFZG5SNWIwaGlOQzh6Wm1wa05rb3pSWFprWVRONFVGazVNVzlYTTNkWlZEWlFiRVJuUWpKSGFUbGlOSFJPYTBJclJYWm1RVGhGVnl0SWVsY3JNVVZIVlZZclMybFhSV1l3WXk5Uk1FNUVVRU5PU0ZGeU9EZFlSM1pqU0U1bGFqZElVSE5SVG1wcU4wRXlOR1V5TTFWR05VdElUSFpPU1dJeU9GcFFVVVpTZEZac09XWklMM1pQS3psVlJrUnVLMHBJWm1oTk5FSlFiemszWkRkcGVETmxWM2R4VmxWM2NqZHBjRU5EVm1keVFUSnVWV1pQTTAxR1NVdFlXbEJRWTI1SGR6Wk1iMGhpTTFKT1VEUlVTR05USzBGWVowNTJaRk5GTDBRMFFsSmlaemt3VVVkRksyb3dNSGRaVkRoRFREUlVSR3RIS3lzdk9GZzBaMlJoYlRKTGFWZDNaamswWmpNeFoxVlBaMjUwV1VOdWMxWTVlVXgwTnk5alp6bDRkM1UzVUhOblZsWm9NMkV4TkV0cGNIRmlhVFZ2WWprMVZGY3ZRVmxIV1haMmJURXpUVVowU3pZNWIwMU5ZamROYUV0TWVUVk5VbWwzY2xaalJHRmthRGczV1VJek0wdENjMDluYlVWa1VucHZTMjltYUhkQkwyTndSblZXTWtoaFdrWkRiMHd6WTJNdk16TjBjR1pEZG1SV2FrSlljMEoyWXk4NU5FbzJTR1p6Wml0NEwyeE1kbU5OZDNKWGFISk1SV1ZyV1VwbldHd3hXR05YWjFwTVVITldRbVUzTTNKNFZXeFdUbXBuTlhObVdUaFFSRWhRVkVVelZXb3pOMEZDT0U4dlFWTkNPWGM1VGtoWlJUTkRkbmRLSzNwRU0zVm5SMkk1ZW10RWJUSkZTMDVuWXpjck4yZEdSSFoyT1VSdVUya3JSMkZhZWtvMmVtOU5UMmx1TlVsSEt6UlhWMEo0Tm1kUmJtVlVZbmQzU21sM2Qwd3lRWEprUXk5cWRFWmlSVlJCUlVsRFFVRkZRVU4zUVZsQlExbEJTMmRCZDBGRVdVRlBkMEpRUVVaalFWaEJRbXBCU0dkQloyZERSMEZOUlVGNVVVUldRVTR3UVRWM1JIWkJVR05CTDFGRlMwRlJORUpHZDBWblFWTmpRa3gzUlRGQlZUQkNXR2RHYUVGWGEwSmpVVVkxUVRGVlJHaFJVQ3RDUTNORlRYZFNSVUpHU1VWbVFWTkZRa3B2UlhKQlV6RkNUVGhGTkhkVU1rSlJhMFpIZDFWMFFsUk5SbEZuVmxKQ1YwRkdZbWRXT0VKWlowWnNRVmRuUW1GM1JuUkJWemhDWTJSMGFrY3JUV0pTTmtOcFoxVk1lbTFrV25KRlVYVklabk5pVEZJd1prTXhkMlF4VDJKd2VFVlpiVXBzU2tkTVVqaE1iME5aWkVNek4xVTVLeTlWUXpOdVdTdFJTak5ESzFWRVVrRnZURGtyZGpoWFVWaFRLMVZCTXk5TE1FZGxTMnd5Y1VoWGNFTkJkamMyTDJoaFFsVkpSME1yUlVSTmVEQk1LekpXTWl0VmVETkRMMk5CS3pOdlZqUkJZak4xVUd4TlFsUlpSeXQ1YWpoQ1NHTmtRekJ3VjJFd2RIQklORXROUWxGMEsxRlJiMHc1TVRFclJtVnlZM1lyYW5CUVlWcEJibEk1VjIxR01tRjBhSEU0ZEdGSE4zTmhNU3RpTmxGbGRuSXdSblJIVmxodVJrbGlUVVE1V2sxVVdGaGhPVTQxU0RGRlMwSldNako1TTBST1IzZDJNMjVRWjFWcFNsVkdRemRVVlVaaGRXdHZZWGx5WTJ4M1MwTXZkVVl3TDJONVZHZHZUR0paZUhacVJ6QmxaMWx2UmtNMGRsZ3JTMWhZWjBwWlRHOUlZalJMVFd4T01VRnpaemw0VkZaM1VYUXliM2xaWkhCWVkxTTNUaTgwU0hRNFRFWlZaMlJFY1VJeU9UZ3pXRGszYURORE5rSXlLMEkzVkRreFZGVkROa0l5SzFCTVYwRlJkVUl4UjBZeUswTnFWVU0wZGxnclMxaFlRelI2TTNkNFZYaFhUbEJ6TjNJM1V6VlpOR1kyYzA1RlNtbGtVMUpUTUdaRE9YTlhNMlpsVjBKMVJ6aDNUMDloYkRSMVMyMVNORXhYZURCUEswTnFORFZ2WVZkQ1VYWlZPWHBFU2psNFlsUkROWEF5SzFWT00yOHpZMHhYZFU4NU0zVTNaR3gwTmxVemNGQmxZM0F5Um1RMlJqTnZTR1l2UVVObFFVRlFPRUZYTkVGQlRrOUpVMjRyYjNNdmQwSnhaMEZFTDBGRFpVRkJUMkl2THpkRFFVRlBZVGt2ZDBKaFowRkNSelZ2VUcwdkx5czBaMEZFWlU5UFlTODFaaTh2Y2xsQlFTOTNRbE5uUVVRdkx6WXJRVUZQWVZFNWQxRnNPRkpRYjB0YVVVRXJRemxoUmxKUFFXZEJRMEU1TTNZelRtWmpORGt6WWpOQ1IxUnpVMDVCWm1ZdmRXZENVazlCUVVGQ1FXTnVUVVp3YmtOYVlVZEZZVmN6YUcxamJrVmxZVWRyUm1OdVNtOW1WMGxpWVVkaFYyOXRPR1poYld0c2VWbDROR0ZIV1c1b1oxVlVOa050VlVGR1VFODFWM0o0Unk5MWNEaDRWVlJKUVZGQlFVaDZNMjkzVlZSSlFtZEJRVXN5ZFVKWVUyeG1URXQ1UjNKUFZYQTJlWE5JY1RaMVFtRmhiWFJLZFRGSE4wdHpabTVQYTBoNFRVRkpRa0ZCY25FM00wTlpXVVpGZDBsQlFrRkRTbUYzVlZSQlEyZEJRVXR4Y1RoWlkwWjVhMk4xY2k5elEwY3ZkRFlyZWxnM1RuWjBORWg0VUc5TFdsRkJLM2R0TWtvNVNrZElhRTFWUVd0QlFUbDZVRE41VWxoamVFMUlWak5zU0VOUmVqbFJWVEJKTm5jeFVGTkllRTVuUVVORlFUazFjamR3ZUZoWWQzSXZaREl4U3psUWEwNVRWMnBaT1hoR1psZEllRTFLUVVKUlFTdDNjak4wUWxocGFEUTNaM2cwWlVsUFQwZEhiSFpsVUVKU1RVbFJRVzlCVGxrMlNFOVdRMDVDVWsxRFFVRm5RV3AwTkVaRmQwbENhMEZCTUdwM1dEZHRMM2wwUm1WSFVXaDFiak5MUXl0T2FrZ3pNMnQ2VjBkclJGQTNTMlZUU21sblZWUkdRVXBCUVZCalZ6ZG9WbnBsUzFOeGNGcHhaSEJMYVZwaGJrcDRaVmgwTVVoNFRtZEJRMFZCT1RWTU4zQjRWbmxtU2padmNWcDFaMjgyVjJGa01qbDVaMGhHZEVoM056UktibXRXT1RFdk0wZG1ZM001TWt3eldYWnpXamw1TXpkWUwzUm1LM2gyTjB4bWRHa3JNa3d6Unk5emN6a3hPR1pXZURNM1RXazNOMFIyYzNSSWQzUTJNUzlsWkhsMlpVRXhhRXhQTkd4UVlqazJXR0pWSzBsVU9IWm1UMlZvV0ROTlQyWnFPWGRVWmxSemJ6SndRaXRTUW5oUWN6QnhUek4zVG5OaE4xUllaQ3Q0WmpkR1ZGRTBTMnAxTWxaMFNucEliMVZJUlM5Sk1HTXhSazFPYUhJM1FrOWplamw1T0dVeGQxRjJVamhFWkRGalprUTNLeTlKVlRCRk5WSnNXWFpJZUZCek9UbDNSVkF3TDBGNlkzcENkamt6WlhkV1pFdFRWVGxYVUdnNFQwSjRUVFpuVG5OSFJURnhRWEZKZFc1cGNXdGxhelIzUmtVMWJVRlNOaXNyWW1SRlltWmtUVlpGTlhsQlYxRnZWRzFaUVhCWFZVMTRhVkkwVDBGa2RtUTVORXB5U0ZGMVoyUjJhRzFuZURCWE0yWm9iVTlSV1ZRNFJFRkxSRzVpTkZwdVpqTnhibU5DTWprd1JHTm9NRXd5WjBoTU5GQm5XalJCVURNM1NITldPVEJRZWpsNldETlhabVJaU1M5amVpc3dVRGRTUTFBM1RTOTBXU3N4Ym5vcmVsZ3pVa0k0VEZaUmIxUnRXVUo2U0ZGMllpc3piMVl6Wm1SYVFuSlhUSEl6WjJRNWVIaEVPWGRFTjBWNE9FdzVOVk5HUm1OQlJ6a3hURFJ6Wm1SVEwweEZSbmRSV1V3eFVHWlJOREF6VldkSVkwdzRTVTFXT1UxdVRUbDNhMllyU1RneUwwbHJTRkV5ZUd4VWJuUTNha2s1TmtobmRtSjRiVFEzVGxaS2FWQkNMemRVZG1aR1JtWmtNamt3WTBoRE9Fb3Zka2gwWTBkc1pHVmtSbHBsV1hGRGRtRlNOVlZYUVhZelpuWjRhRUphWjBjNU16YzBXalZYWm13MllWZHdVbXRNUWxKUWJ5OUVOQzg1ZWsxSGRISjFUV3BNVldZck1EUk1OMEppTTNOM1lqTkVPVE5YT1hkeWNWVmlaRU51VWpoTVdIZ3pNM1JPZDB4Q1ptTkRRblZRUTFWNmJ6UlZNRlZ6VEZaWlREa3liVVpHWkVWSE9URnFOR0ZuVjA1T1oyTk1NbVptVkRFdlkzQXhaMGcwV0dRMFJEazRRVXhNUmt4U09FOHZSVEIxY210MmEwMXdTSGQyYzBaMEx6UnZVV0ZZWTFwa2QyeFlZMGxETDNOVmFtZzRWREpRWkZNNU5VZElRelpHY21GdVRqRmhNbkZxWkdGM1prTXZkR3hrZG1SM01WQm1jREZKUWpORE1sVm1hWGRsVm5vMVZGRnJPSGRKUTNkSEx6TjJabGN6WjAxTVpIWm5iekZRWlV4a2QzWTNUVUpZU1VKMlVETjFRVmRPUTNkQlFVRkJSVUZCUVVGTlFVRkJRVUZCUVVGQlFVbEJRVkZCUTBGRVZVRkJVVUZCUVhwalFVWkJSSGRCUVVGRGNrRkJaRUZ3UVVGWlVVeG5RVVZCUXpCQlFtaEJhekJCV1ZGSmEwRkhSVVJEWjBKQlFYVlJRVmxSUlZkQlIwVkNZbEZCYTBGd1JVRlpVVWx1UVVkRlJHcDNRbWhCZGxGQldWRk5hVUZGUVVOU1VVSm9RWGxOUVZGQlMxRkJSMFZEVVhkQk1rRnBSVUZEZDB4TVFVWlpRM0puUVdSQksyTkJTWGRMTDBGRVRVTlJkMEZEUVc1blFVbG5Ta05CUXpoRFVXZENVVUZtYTBGTWQwcERRVU00UTBKQlFYWkJWMmRCVEVGS1JFRkRPRU5NWjBKUlFWQkpRVkZCUkhsQlJVRkNOM2RDVVVGUVNVRlZRVTVHUVVaQlEweG5RbEZCYVhOQlRIZEtRMEZHUVVOUlowRjJRVlk0UVZWQlIyWkJRbmRDVmtGQmMwRnBZMEZVUVVoNFFVSk5RelYzUVZSQlpqUkJTVkZJTkVGQ1RVSjFRVUZUUVhFNFFWRkJSamRCUTNkRFZrRkJla0ZyTUVGTFFVcGFRVUpyUTFWQlFYZEJiRUZCVGtGSlZrRkNXVU5rUVVKRVFXeEJRVTVCUkhCQlJGbEJOVUZCVVVGUVFVRkJRVDA5S1R0OUxuQnZiSGxVWlhoMElIdG1iMjUwTFdaaGJXbHNlVG9nSjFCdmJIbFVaWGgwSnp0OVBDOXpkSGxzWlQ0OFpHVm1jejQ4YkdsdVpXRnlSM0poWkdsbGJuUWdhV1E5SjJkeVlXUnBaVzUwSnlCNE1UMG5NQ1VuSUhreFBTY3dKU2NnZURJOUp6QWxKeUI1TWowbk1UQXdKU2MrUEhOMGIzQWdiMlptYzJWMFBTY3dKU2NnYzNSNWJHVTlKM04wYjNBdFkyOXNiM0k2STBaR1JrWkdSanR6ZEc5d0xXOXdZV05wZEhrNk1DNDBKeUF2UGp4emRHOXdJRzltWm5ObGREMG5NVEF3SlNjZ2MzUjViR1U5SjNOMGIzQXRZMjlzYjNJNkkwWkdSa1pHUmp0emRHOXdMVzl3WVdOcGRIazZNQ2NnTHo0OEwyeHBibVZoY2tkeVlXUnBaVzUwUGp4d1lYUm9JR2xrUFNkMGIzQXRjMlZ0YVMxamFYSmpiR1VuSUdROUowMGdOakFzTVRBd0lFRWdOREFzTkRBZ01DQXhMREVnTVRRd0xERXdNQ2NnTHo0OGNHRjBhQ0JwWkQwblltOTBkRzl0TFhObGJXa3RZMmx5WTJ4bEp5QmtQU2ROSURFME1Dd3hNREFnUVNBME1DdzBNQ0F3SURFc01TQTJNQ3d4TURBbklDOCtQQzlrWldaelBqeG5JSFJ5WVc1elptOXliVDBuZEhKaGJuTnNZWFJsS0RVc0lEVXBJSE5qWVd4bEtETXBKejQ4Y0dGMGFDQmtQU2ROTkRBdU1ETTFOaUF5TGpBMk5qSTFRelF5TGpreU16Z2dMVEF1TmpnNE56VXhJRFEzTGpRMk5qa2dMVEF1TmpnNE56VXhJRFV3TGpNMU5URWdNaTR3TmpZeU5WWXlMakEyTmpJMVF6VXlMak01T1RJZ05DNHdNVFl4TVNBMU5TNHpOamM1SURRdU5qUTNNVElnTlRndU1ESTROQ0F6TGpZNU56STJWak11TmprM01qWkROakV1TnpnM05DQXlMak0xTlRFNElEWTFMamt6TnpjZ05DNHlNRE13TWlBMk55NDBOVFUzSURjdU9EazBOVGhXTnk0NE9UUTFPRU0yT0M0MU15QXhNQzQxTURjeklEY3dMams0TlRRZ01USXVNamt4TWlBM015NDRNREl5SURFeUxqVXdOVFpXTVRJdU5UQTFOa00zTnk0M09ESXlJREV5TGpnd09EVWdPREF1T0RJeU1TQXhOaTR4T0RRM0lEZ3dMamN3TnpNZ01qQXVNVGMwTlZZeU1DNHhOelExUXpnd0xqWXlOakVnTWpJdU9UazRNeUE0TWk0eE5ETTJJREkxTGpZeU5qY2dPRFF1TmpJNU55QXlOaTQ1TmpneVZqSTJMamsyT0RKRE9EZ3VNVFF5TXlBeU9DNDROak0zSURnNUxqVTBOaklnTXpNdU1UZzBOQ0E0Tnk0NE1UZzJJRE0yTGpjNE1qWldNell1TnpneU5rTTROaTQxT1RVNElETTVMak15T1RJZ09EWXVPVEV6TVNBME1pNHpORGMySURnNExqWXpPRFlnTkRRdU5UZzBORlkwTkM0MU9EUTBRemt4TGpBM05qWWdORGN1TnpRME55QTVNQzQyTURFM0lEVXlMakkyTWprZ09EY3VOVFU1T1NBMU5DNDRORGN6VmpVMExqZzBOek5ET0RVdU5EQTNJRFUyTGpZM05qVWdPRFF1TkRZNU1pQTFPUzQxTmpJNUlEZzFMakV6TlRjZ05qSXVNekE0TVZZMk1pNHpNRGd4UXpnMkxqQTNOelVnTmpZdU1UZzJPU0E0TXk0NE1EWWdOekF1TVRJeE15QTNPUzQ1TnpZZ056RXVNalExTVZZM01TNHlORFV4UXpjM0xqSTJOVE1nTnpJdU1EUXdOQ0EzTlM0eU16UTFJRGMwTGpJNU5Ua2dOelF1TnpJMk9DQTNOeTR3TnpRNFZqYzNMakEzTkRoRE56UXVNREE1TmlBNE1TNHdNREV6SURjd0xqTXpOREVnT0RNdU5qY3hOeUEyTmk0ek56Z3lJRGd6TGpFME1EVldPRE11TVRRd05VTTJNeTQxTnpnMElEZ3lMamMyTkRVZ05qQXVPREExTnlBNE15NDVPVGtnTlRrdU1qRXhOeUE0Tmk0ek16RXlWamcyTGpNek1USkROVFl1T1RVNU5DQTRPUzQyTWpZMUlEVXlMalV4TlRZZ09UQXVOVGN4TVNBME9TNHhNVGMzSURnNExqUTNOamhXT0RndU5EYzJPRU0wTmk0M01USTRJRGcyTGprNU5EVWdORE11TmpjM09DQTROaTQ1T1RRMUlEUXhMakkzTXlBNE9DNDBOelk0VmpnNExqUTNOamhETXpjdU9EYzFNU0E1TUM0MU56RXhJRE16TGpRek1UTWdPRGt1TmpJMk5TQXpNUzR4TnprZ09EWXVNek14TWxZNE5pNHpNekV5UXpJNUxqVTRORGtnT0RNdU9UazVJREkyTGpneE1qTWdPREl1TnpZME5TQXlOQzR3TVRJMUlEZ3pMakUwTURWV09ETXVNVFF3TlVNeU1DNHdOVFkxSURnekxqWTNNVGNnTVRZdU16Z3hNU0E0TVM0d01ERXpJREUxTGpZMk16Z2dOemN1TURjME9GWTNOeTR3TnpRNFF6RTFMakUxTmpJZ056UXVNamsxT1NBeE15NHhNalV6SURjeUxqQTBNRFFnTVRBdU5ERTBOeUEzTVM0eU5EVXhWamN4TGpJME5URkROaTQxT0RRMk5TQTNNQzR4TWpFeklEUXVNekV6TVRFZ05qWXVNVGcyT1NBMUxqSTFORGt4SURZeUxqTXdPREZXTmpJdU16QTRNVU0xTGpreU1UUTNJRFU1TGpVMk1qa2dOQzQ1T0RNMklEVTJMalkzTmpVZ01pNDRNekEzTmlBMU5DNDRORGN6VmpVMExqZzBOek5ETFRBdU1qRXhNRFUwSURVeUxqSTJNamtnTFRBdU5qZzFPVE0zSURRM0xqYzBORGNnTVM0M05USXdOeUEwTkM0MU9EUTBWalEwTGpVNE5EUkRNeTQwTnpjMU9DQTBNaTR6TkRjMklETXVOemswT0RJZ016a3VNekk1TXlBeUxqVTNNakEzSURNMkxqYzRNalpXTXpZdU56Z3lOa013TGpnME5EUXhNU0F6TXk0eE9EUTBJREl1TWpRNE15QXlPQzQ0TmpNM0lEVXVOell3T1RjZ01qWXVPVFk0TWxZeU5pNDVOamd5UXpndU1qUTNNRFlnTWpVdU5qSTJOeUE1TGpjMk5EVTNJREl5TGprNU9ETWdPUzQyT0RNek15QXlNQzR4TnpRMVZqSXdMakUzTkRWRE9TNDFOamcxTlNBeE5pNHhPRFEzSURFeUxqWXdPRFVnTVRJdU9EQTROU0F4Tmk0MU9EZzBJREV5TGpVd05UWldNVEl1TlRBMU5rTXhPUzQwTURVeUlERXlMakk1TVRJZ01qRXVPRFl3TmlBeE1DNDFNRGN6SURJeUxqa3pORGtnTnk0NE9UUTFPRlkzTGpnNU5EVTRRekkwTGpRMU1qa2dOQzR5TURNd01pQXlPQzQyTURNeUlESXVNelUxTVRnZ016SXVNell5TXlBekxqWTVOekkyVmpNdU5qazNNalpETXpVdU1ESXlOeUEwTGpZME56RXlJRE0zTGprNU1UUWdOQzR3TVRZeE1TQTBNQzR3TXpVMklESXVNRFkyTWpWV01pNHdOall5TlZvbklHWnBiR3c5SnlOR1JqZ3lRVVFuSUhOMGNtOXJaVDBuSXpBd01DY2djM1J5YjJ0bExYZHBaSFJvUFNjekp5QXZQand2Wno0OFp5QjBjbUZ1YzJadmNtMDlKM1J5WVc1emJHRjBaU2d0TlRVc0lDMDJNQ2tnYzJOaGJHVW9NaWtuUGp4MFpYaDBJSGc5SnpBbklIazlKekFuSUdadmJuUXRjMmw2WlQwbk1UQW5JR1pwYkd3OUp5TkdSa1luSUdOc1lYTnpQU2R3YjJ4NVZHVjRkQ2MrUEhSbGVIUlFZWFJvSUdoeVpXWTlKeU4wYjNBdGMyVnRhUzFqYVhKamJHVW5JSE4wWVhKMFQyWm1jMlYwUFNjME1DVW5JSFJsZUhRdFlXNWphRzl5UFNkdGFXUmtiR1VuUGtrZ1UxVlFVRTlTVkNCSlJFVkJJREU4TDNSbGVIUlFZWFJvUGp3dmRHVjRkRDQ4ZEdWNGRDQjRQU2N3SnlCNVBTY3dKeUJtYjI1MExYTnBlbVU5SnpFd0p5Qm1hV3hzUFNjalJrWkdKeUJqYkdGemN6MG5jRzlzZVZSbGVIUW5QangwWlhoMFVHRjBhQ0JvY21WbVBTY2pZbTkwZEc5dExYTmxiV2t0WTJseVkyeGxKeUJ6ZEdGeWRFOW1abk5sZEQwbk5EQWxKeUIwWlhoMExXRnVZMmh2Y2owbmJXbGtaR3hsSno1SklGTlZVRkJQVWxRZ1NVUkZRU0F4UEM5MFpYaDBVR0YwYUQ0OEwzUmxlSFErUEdjZ2RISmhibk5tYjNKdFBTZDBjbUZ1YzJ4aGRHVW9OakVzSURnM0tTQnpZMkZzWlNndU1qQXBJSEp2ZEdGMFpTZ3RNakFwSno0OGNtVmpkQ0IzYVdSMGFEMGlPREFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakV5TUNJZ2VUMGlOVEFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqTXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSTVNQ0lnZVQwaU5qQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpNd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeE1qQWlJSGs5SWpZd0lpQm1hV3hzUFNJalptWTJNemhrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTVRVd0lpQjVQU0kyTUNJZ1ptbHNiRDBpSTJabU9ESmhaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlOREFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakUyTUNJZ2VUMGlOakFpSUdacGJHdzlJaU5tWmpZek9HUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqTXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXlNREFpSUhrOUlqWXdJaUJtYVd4c1BTSWpabVk0TW1Ga0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU9EQWlJSGs5SWpjd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l6TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpT1RBaUlIazlJamN3SWlCbWFXeHNQU0lqWm1ZMk16aGtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXpNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVEl3SWlCNVBTSTNNQ0lnWm1sc2JEMGlJMlptT0RKaFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1UQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqRTFNQ0lnZVQwaU56QWlJR1pwYkd3OUlpTm1aall6T0dRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpRd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeE5qQWlJSGs5SWpjd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l6TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTWpBd0lpQjVQU0kzTUNJZ1ptbHNiRDBpSTJabU5qTTRaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNVEFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakl6TUNJZ2VUMGlOekFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSTNNQ0lnZVQwaU9EQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpFd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJNE1DSWdlVDBpT0RBaUlHWnBiR3c5SWlObVpqWXpPR1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakl3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0k1TUNJZ2VUMGlPREFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXhNVEFpSUhrOUlqZ3dJaUJtYVd4c1BTSWpabVkyTXpoa0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1USXdJaUI1UFNJNE1DSWdabWxzYkQwaUkyWm1PREpoWkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpFek1DSWdlVDBpT0RBaUlHWnBiR3c5SWlObVpqWXpPR1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l4TkRBaUlIazlJamd3SWlCbWFXeHNQU0lqWm1ZNE1tRmtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVFV3SWlCNVBTSTRNQ0lnWm1sc2JEMGlJMlptTmpNNFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1UQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqRTJNQ0lnZVQwaU9EQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpFd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeE56QWlJSGs5SWpnd0lpQm1hV3hzUFNJalptWTJNemhrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l5TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTVRnd0lpQjVQU0k0TUNJZ1ptbHNiRDBpSTJabU9ESmhaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNVEFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakl3TUNJZ2VUMGlPREFpSUdacGJHdzlJaU5tWmpZek9HUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqSXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXlNVEFpSUhrOUlqZ3dJaUJtYVd4c1BTSWpabVk0TW1Ga0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1qTXdJaUI1UFNJNE1DSWdabWxzYkQwaUkyWm1Oak00WkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpJME1DSWdlVDBpT0RBaUlHWnBiR3c5SWlObVpqZ3lZV1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0kzTUNJZ2VUMGlPVEFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSTRNQ0lnZVQwaU9UQWlJR1pwYkd3OUlpTm1aall6T0dRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpFd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJNU1DSWdlVDBpT1RBaUlHWnBiR3c5SWlObVpqZ3lZV1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l4TURBaUlIazlJamt3SWlCbWFXeHNQU0lqWm1ZMk16aGtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXlNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVEV3SWlCNVBTSTVNQ0lnWm1sc2JEMGlJMlptT0RKaFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1UQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqRXpNQ0lnZVQwaU9UQWlJR1pwYkd3OUlpTm1aall6T0dRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpJd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeE5EQWlJSGs5SWprd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTVRZd0lpQjVQU0k1TUNJZ1ptbHNiRDBpSTJabU5qTTRaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNakFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakUzTUNJZ2VUMGlPVEFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXhPVEFpSUhrOUlqa3dJaUJtYVd4c1BTSWpabVkyTXpoa0lpQXZQanh5WldOMElIZHBaSFJvUFNJMU1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1qQXdJaUI1UFNJNU1DSWdabWxzYkQwaUkyWm1PREpoWkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTmpBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpZd0lpQjVQU0l4TURBaUlHWnBiR3c5SWlObVpqZ3lZV1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l4TWpBaUlIazlJakV3TUNJZ1ptbHNiRDBpSTJabU5qTTRaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNekFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakV6TUNJZ2VUMGlNVEF3SWlCbWFXeHNQU0lqWm1ZNE1tRmtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVFl3SWlCNVBTSXhNREFpSUdacGJHdzlJaU5tWmpZek9HUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqSXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXhOekFpSUhrOUlqRXdNQ0lnWm1sc2JEMGlJMlptT0RKaFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1UQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqRTVNQ0lnZVQwaU1UQXdJaUJtYVd4c1BTSWpabVkyTXpoa0lpQXZQanh5WldOMElIZHBaSFJvUFNJeU1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1qQXdJaUI1UFNJeE1EQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpFd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeU1qQWlJSGs5SWpFd01DSWdabWxzYkQwaUkyWm1Oak00WkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpJek1DSWdlVDBpTVRBd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTWpRd0lpQjVQU0l4TURBaUlHWnBiR3c5SWlObVpqWXpPR1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l5TlRBaUlIazlJakV3TUNJZ1ptbHNiRDBpSTJabU9ESmhaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNVEFpSUdobGFXZG9kRDBpTVRBaUlIZzlJall3SWlCNVBTSXhNVEFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSTNNQ0lnZVQwaU1URXdJaUJtYVd4c1BTSWpabVkyTXpoa0lpQXZQanh5WldOMElIZHBaSFJvUFNJME1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU9EQWlJSGs5SWpFeE1DSWdabWxzYkQwaUkyWm1PREpoWkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpFeU1DSWdlVDBpTVRFd0lpQm1hV3hzUFNJalptWTJNemhrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0kyTUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTVRNd0lpQjVQU0l4TVRBaUlHWnBiR3c5SWlObVpqZ3lZV1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l4T1RBaUlIazlJakV4TUNJZ1ptbHNiRDBpSTJabU5qTTRaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlOREFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakl3TUNJZ2VUMGlNVEV3SWlCbWFXeHNQU0lqWm1ZNE1tRmtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNalF3SWlCNVBTSXhNVEFpSUdacGJHdzlJaU5tWmpZek9HUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXlOVEFpSUhrOUlqRXhNQ0lnWm1sc2JEMGlJMlptT0RKaFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1UQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqWXdJaUI1UFNJeE1qQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpFd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJM01DSWdlVDBpTVRJd0lpQm1hV3hzUFNJalptWTJNemhrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l5TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpT0RBaUlIazlJakV5TUNJZ1ptbHNiRDBpSTJabU9ESmhaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNVEFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakV3TUNJZ2VUMGlNVEl3SWlCbWFXeHNQU0lqWm1ZMk16aGtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXlNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVEV3SWlCNVBTSXhNakFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXhNekFpSUhrOUlqRXlNQ0lnWm1sc2JEMGlJMlptTmpNNFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU16QWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqRTBNQ0lnZVQwaU1USXdJaUJtYVd4c1BTSWpabVk0TW1Ga0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1UY3dJaUI1UFNJeE1qQWlJR1pwYkd3OUlpTm1aall6T0dRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpZd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeE9EQWlJSGs5SWpFeU1DSWdabWxzYkQwaUkyWm1PREpoWkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpJME1DSWdlVDBpTVRJd0lpQm1hV3hzUFNJalptWTJNemhrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTWpVd0lpQjVQU0l4TWpBaUlHWnBiR3c5SWlObVpqZ3lZV1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJalF3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0kyTUNJZ2VUMGlNVE13SWlCbWFXeHNQU0lqWm1ZNE1tRmtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVEF3SWlCNVBTSXhNekFpSUdacGJHdzlJaU5tWmpZek9HUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqSXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXhNVEFpSUhrOUlqRXpNQ0lnWm1sc2JEMGlJMlptT0RKaFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1UQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqRXpNQ0lnZVQwaU1UTXdJaUJtYVd4c1BTSWpabVkyTXpoa0lpQXZQanh5WldOMElIZHBaSFJvUFNJME1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1UUXdJaUI1UFNJeE16QWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpFd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeE9EQWlJSGs5SWpFek1DSWdabWxzYkQwaUkyWm1Oak00WkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpFNU1DSWdlVDBpTVRNd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l5TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTWpBd0lpQjVQU0l4TXpBaUlHWnBiR3c5SWlObVpqWXpPR1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakl3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l5TWpBaUlIazlJakV6TUNJZ1ptbHNiRDBpSTJabU9ESmhaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNVEFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakkwTUNJZ2VUMGlNVE13SWlCbWFXeHNQU0lqWm1ZMk16aGtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNalV3SWlCNVBTSXhNekFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSTJNQ0lnZVQwaU1UUXdJaUJtYVd4c1BTSWpabVk0TW1Ga0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU56QWlJSGs5SWpFME1DSWdabWxzYkQwaUkyWm1Oak00WkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTWpBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpnd0lpQjVQU0l4TkRBaUlHWnBiR3c5SWlObVpqZ3lZV1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l4TURBaUlIazlJakUwTUNJZ1ptbHNiRDBpSTJabU5qTTRaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNekFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakV4TUNJZ2VUMGlNVFF3SWlCbWFXeHNQU0lqWm1ZNE1tRmtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVFF3SWlCNVBTSXhOREFpSUdacGJHdzlJaU5tWmpZek9HUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqa3dJaUJvWldsbmFIUTlJakV3SWlCNFBTSXhOVEFpSUhrOUlqRTBNQ0lnWm1sc2JEMGlJMlptT0RKaFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1UQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqSTBNQ0lnZVQwaU1UUXdJaUJtYVd4c1BTSWpabVkyTXpoa0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1qVXdJaUI1UFNJeE5EQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpFd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJMk1DSWdlVDBpTVRVd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTnpBaUlIazlJakUxTUNJZ1ptbHNiRDBpSTJabU5qTTRaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNekFpSUdobGFXZG9kRDBpTVRBaUlIZzlJamd3SWlCNVBTSXhOVEFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXhNVEFpSUhrOUlqRTFNQ0lnWm1sc2JEMGlJMlptTmpNNFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU5UQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqRXlNQ0lnZVQwaU1UVXdJaUJtYVd4c1BTSWpabVk0TW1Ga0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1UY3dJaUI1UFNJeE5UQWlJR1pwYkd3OUlpTm1aall6T0dRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpZd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeE9EQWlJSGs5SWpFMU1DSWdabWxzYkQwaUkyWm1PREpoWkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpJME1DSWdlVDBpTVRVd0lpQm1hV3hzUFNJalptWTJNemhrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTWpVd0lpQjVQU0l4TlRBaUlHWnBiR3c5SWlObVpqZ3lZV1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJall3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0kyTUNJZ2VUMGlNVFl3SWlCbWFXeHNQU0lqWm1ZNE1tRmtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVEl3SWlCNVBTSXhOakFpSUdacGJHdzlJaU5tWmpZek9HUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqVXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXhNekFpSUhrOUlqRTJNQ0lnWm1sc2JEMGlJMlptT0RKaFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1qQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqRTRNQ0lnZVQwaU1UWXdJaUJtYVd4c1BTSWpabVkyTXpoa0lpQXZQanh5WldOMElIZHBaSFJvUFNJME1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU1qQXdJaUI1UFNJeE5qQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpFd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeU5EQWlJSGs5SWpFMk1DSWdabWxzYkQwaUkyWm1Oak00WkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpJMU1DSWdlVDBpTVRZd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4T0RBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpjd0lpQjVQU0l4TnpBaUlHWnBiR3c5SWlObVpqZ3lZV1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0kzTUNJZ2VUMGlNVGd3SWlCbWFXeHNQU0lqWm1ZNE1tRmtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlPREFpSUhrOUlqRTRNQ0lnWm1sc2JEMGlJMlptTmpNNFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU16QWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqa3dJaUI1UFNJeE9EQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQSEpsWTNRZ2QybGtkR2c5SWpJd0lpQm9aV2xuYUhROUlqRXdJaUI0UFNJeE1qQWlJSGs5SWpFNE1DSWdabWxzYkQwaUkyWm1Oak00WkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTWpBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpFME1DSWdlVDBpTVRnd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTVRZd0lpQjVQU0l4T0RBaUlHWnBiR3c5SWlObVpqWXpPR1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJalV3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l4TnpBaUlIazlJakU0TUNJZ1ptbHNiRDBpSTJabU9ESmhaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNakFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakl5TUNJZ2VUMGlNVGd3SWlCbWFXeHNQU0lqWm1ZMk16aGtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSXhNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNalF3SWlCNVBTSXhPREFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqRXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSTRNQ0lnZVQwaU1Ua3dJaUJtYVd4c1BTSWpabVk0TW1Ga0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE1DSWdhR1ZwWjJoMFBTSXhNQ0lnZUQwaU9UQWlJSGs5SWpFNU1DSWdabWxzYkQwaUkyWm1Oak00WkNJZ0x6NDhjbVZqZENCM2FXUjBhRDBpTVRBaUlHaGxhV2RvZEQwaU1UQWlJSGc5SWpFd01DSWdlVDBpTVRrd0lpQm1hV3hzUFNJalptWTRNbUZrSWlBdlBqeHlaV04wSUhkcFpIUm9QU0l4TUNJZ2FHVnBaMmgwUFNJeE1DSWdlRDBpTVRFd0lpQjVQU0l4T1RBaUlHWnBiR3c5SWlObVpqWXpPR1FpSUM4K1BISmxZM1FnZDJsa2RHZzlJakl3SWlCb1pXbG5hSFE5SWpFd0lpQjRQU0l4TWpBaUlIazlJakU1TUNJZ1ptbHNiRDBpSTJabU9ESmhaQ0lnTHo0OGNtVmpkQ0IzYVdSMGFEMGlNakFpSUdobGFXZG9kRDBpTVRBaUlIZzlJakUwTUNJZ2VUMGlNVGt3SWlCbWFXeHNQU0lqWm1ZMk16aGtJaUF2UGp4eVpXTjBJSGRwWkhSb1BTSTBNQ0lnYUdWcFoyaDBQU0l4TUNJZ2VEMGlNVFl3SWlCNVBTSXhPVEFpSUdacGJHdzlJaU5tWmpneVlXUWlJQzgrUEhKbFkzUWdkMmxrZEdnOUlqSXdJaUJvWldsbmFIUTlJakV3SWlCNFBTSXlNREFpSUhrOUlqRTVNQ0lnWm1sc2JEMGlJMlptTmpNNFpDSWdMejQ4Y21WamRDQjNhV1IwYUQwaU1qQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqSXlNQ0lnZVQwaU1Ua3dJaUJtYVd4c1BTSWpabVk0TW1Ga0lpQXZQanh5WldOMElIZHBaSFJvUFNJeE5EQWlJR2hsYVdkb2REMGlNVEFpSUhnOUlqa3dJaUI1UFNJeU1EQWlJR1pwYkd3OUlpTm1aamd5WVdRaUlDOCtQQzluUGp3dlp6NDhaeUIwY21GdWMyWnZjbTA5SjNSeVlXNXpiR0YwWlNnMUxDQTFLU0J6WTJGc1pTZ3pLU2MrUEhCaGRHZ2daRDBuVFRRd0xqQXpOVFlnTWk0d05qWXlOVU0wTWk0NU1qTTRJQzB3TGpZNE9EYzFNU0EwTnk0ME5qWTVJQzB3TGpZNE9EYzFNU0ExTUM0ek5UVXhJREl1TURZMk1qVldNaTR3TmpZeU5VTTFNaTR6T1RreUlEUXVNREUyTVRFZ05UVXVNelkzT1NBMExqWTBOekV5SURVNExqQXlPRFFnTXk0Mk9UY3lObFl6TGpZNU56STJRell4TGpjNE56UWdNaTR6TlRVeE9DQTJOUzQ1TXpjM0lEUXVNakF6TURJZ05qY3VORFUxTnlBM0xqZzVORFU0VmpjdU9EazBOVGhETmpndU5UTWdNVEF1TlRBM015QTNNQzQ1T0RVMElERXlMakk1TVRJZ056TXVPREF5TWlBeE1pNDFNRFUyVmpFeUxqVXdOVFpETnpjdU56Z3lNaUF4TWk0NE1EZzFJRGd3TGpneU1qRWdNVFl1TVRnME55QTRNQzQzTURjeklESXdMakUzTkRWV01qQXVNVGMwTlVNNE1DNDJNall4SURJeUxqazVPRE1nT0RJdU1UUXpOaUF5TlM0Mk1qWTNJRGcwTGpZeU9UY2dNall1T1RZNE1sWXlOaTQ1TmpneVF6ZzRMakUwTWpNZ01qZ3VPRFl6TnlBNE9TNDFORFl5SURNekxqRTRORFFnT0RjdU9ERTROaUF6Tmk0M09ESTJWak0yTGpjNE1qWkRPRFl1TlRrMU9DQXpPUzR6TWpreUlEZzJMamt4TXpFZ05ESXVNelEzTmlBNE9DNDJNemcySURRMExqVTRORFJXTkRRdU5UZzBORU01TVM0d056WTJJRFEzTGpjME5EY2dPVEF1TmpBeE55QTFNaTR5TmpJNUlEZzNMalUxT1RrZ05UUXVPRFEzTTFZMU5DNDRORGN6UXpnMUxqUXdOeUExTmk0Mk56WTFJRGcwTGpRMk9USWdOVGt1TlRZeU9TQTROUzR4TXpVM0lEWXlMak13T0RGV05qSXVNekE0TVVNNE5pNHdOemMxSURZMkxqRTROamtnT0RNdU9EQTJJRGN3TGpFeU1UTWdOemt1T1RjMklEY3hMakkwTlRGV056RXVNalExTVVNM055NHlOalV6SURjeUxqQTBNRFFnTnpVdU1qTTBOU0EzTkM0eU9UVTVJRGMwTGpjeU5qZ2dOemN1TURjME9GWTNOeTR3TnpRNFF6YzBMakF3T1RZZ09ERXVNREF4TXlBM01DNHpNelF4SURnekxqWTNNVGNnTmpZdU16YzRNaUE0TXk0eE5EQTFWamd6TGpFME1EVkROak11TlRjNE5DQTRNaTQzTmpRMUlEWXdMamd3TlRjZ09ETXVPVGs1SURVNUxqSXhNVGNnT0RZdU16TXhNbFk0Tmk0ek16RXlRelUyTGprMU9UUWdPRGt1TmpJMk5TQTFNaTQxTVRVMklEa3dMalUzTVRFZ05Ea3VNVEUzTnlBNE9DNDBOelk0VmpnNExqUTNOamhETkRZdU56RXlPQ0E0Tmk0NU9UUTFJRFF6TGpZM056Z2dPRFl1T1RrME5TQTBNUzR5TnpNZ09EZ3VORGMyT0ZZNE9DNDBOelk0UXpNM0xqZzNOVEVnT1RBdU5UY3hNU0F6TXk0ME16RXpJRGc1TGpZeU5qVWdNekV1TVRjNUlEZzJMak16TVRKV09EWXVNek14TWtNeU9TNDFPRFE1SURnekxqazVPU0F5Tmk0NE1USXpJRGd5TGpjMk5EVWdNalF1TURFeU5TQTRNeTR4TkRBMVZqZ3pMakUwTURWRE1qQXVNRFUyTlNBNE15NDJOekUzSURFMkxqTTRNVEVnT0RFdU1EQXhNeUF4TlM0Mk5qTTRJRGMzTGpBM05EaFdOemN1TURjME9FTXhOUzR4TlRZeUlEYzBMakk1TlRrZ01UTXVNVEkxTXlBM01pNHdOREEwSURFd0xqUXhORGNnTnpFdU1qUTFNVlkzTVM0eU5EVXhRell1TlRnME5qVWdOekF1TVRJeE15QTBMak14TXpFeElEWTJMakU0TmprZ05TNHlOVFE1TVNBMk1pNHpNRGd4VmpZeUxqTXdPREZETlM0NU1qRTBOeUExT1M0MU5qSTVJRFF1T1Rnek5pQTFOaTQyTnpZMUlESXVPRE13TnpZZ05UUXVPRFEzTTFZMU5DNDRORGN6UXkwd0xqSXhNVEExTkNBMU1pNHlOakk1SUMwd0xqWTROVGt6TnlBME55NDNORFEzSURFdU56VXlNRGNnTkRRdU5UZzBORlkwTkM0MU9EUTBRek11TkRjM05UZ2dOREl1TXpRM05pQXpMamM1TkRneUlETTVMak15T1RNZ01pNDFOekl3TnlBek5pNDNPREkyVmpNMkxqYzRNalpETUM0NE5EUTBNVEVnTXpNdU1UZzBOQ0F5TGpJME9ETWdNamd1T0RZek55QTFMamMyTURrM0lESTJMamsyT0RKV01qWXVPVFk0TWtNNExqSTBOekEySURJMUxqWXlOamNnT1M0M05qUTFOeUF5TWk0NU9UZ3pJRGt1Tmpnek16TWdNakF1TVRjME5WWXlNQzR4TnpRMVF6a3VOVFk0TlRVZ01UWXVNVGcwTnlBeE1pNDJNRGcxSURFeUxqZ3dPRFVnTVRZdU5UZzROQ0F4TWk0MU1EVTJWakV5TGpVd05UWkRNVGt1TkRBMU1pQXhNaTR5T1RFeUlESXhMamcyTURZZ01UQXVOVEEzTXlBeU1pNDVNelE1SURjdU9EazBOVGhXTnk0NE9UUTFPRU15TkM0ME5USTVJRFF1TWpBek1ESWdNamd1TmpBek1pQXlMak0xTlRFNElETXlMak0yTWpNZ015NDJPVGN5TmxZekxqWTVOekkyUXpNMUxqQXlNamNnTkM0Mk5EY3hNaUF6Tnk0NU9URTBJRFF1TURFMk1URWdOREF1TURNMU5pQXlMakEyTmpJMVZqSXVNRFkyTWpWYUp5Qm1hV3hzUFNkMWNtd29JMmR5WVdScFpXNTBLU2NnYzNSeWIydGxQU2NqTURBd0p5QnpkSEp2YTJVdGQybGtkR2c5SnpNbklDOCtQQzluUGp3dmMzWm5QZz09In0=";
        assertEq(json, correct);
    }
}
