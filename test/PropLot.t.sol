// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IPropLot} from "src/interfaces/IPropLot.sol";
import {PropLot} from "src/PropLot.sol";
import {PropLotHarness} from "test/harness/PropLotHarness.sol";
import {NounsEnvSetup} from "test/helpers/NounsEnvSetup.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

/// @notice Fuzz iteration params can be increased to larger types to match implementation
/// They are temporarily set to smaller types for speed only
/// @dev This IdeaTokenHub test suite inherits from the Nouns governance setup contract to mimic the onchain environment
contract PropLotTest is NounsEnvSetup, TestUtils {

    PropLotHarness propLot;
    IdeaTokenHub ideaTokenHub;

    string uri;
    NounsDAOV3Proposals.ProposalTxs txs;
    string description;
    // for fuzzing purposes, should remain empty until `numEligibleProposers` is known
    IPropLot.Proposal[] proposals;

    address nounderSupplement;
    address nounderSupplement2;
    address nounderSolo;

    // copied from PropLot to facilitate event testing
    event DelegateCreated(address delegate, uint256 id);
    event DelegationRegistered(IPropLot.Delegation optimisticDelegation);
    event DelegationDeleted(IPropLot.Delegation disqualifiedDelegation);


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

        // balances to roughly mirror mainnet
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsForkEscrow_), 265);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(nounsDAOSafe_, 30);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71, 308);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsTokenHarness), 25);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(0x1), 370); // ~rest of missing supply to dummy address

        // mint 1 token to nounderSupplement
        nounderSupplement = vm.addr(0xc0ffeebabe);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSupplement), 0);
        NounsTokenHarness(address(nounsTokenHarness)).mintTo(nounderSupplement);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSupplement), 1);
        
        // mint 1 token to nounderSupplement2
        nounderSupplement2 = vm.addr(0xc0ffeebae);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSupplement2), 0);
        NounsTokenHarness(address(nounsTokenHarness)).mintTo(nounderSupplement2);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSupplement2), 1);
        
        // mint 2 tokens to nounderSolo
        nounderSolo = vm.addr(0xbeefEbabe);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSolo), 0);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(nounderSolo, 2);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSolo), 1);
    }

    function test_setUp() public {
        assertEq(address(nounsTokenHarness), address(nounsGovernorProxy.nouns()));
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).balanceOf(nounderSupplement), 1);
        assertEq(propLot.getOptimisticDelegations().length, 0);
        
        uint256 totalSupply = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).ownerOf(totalSupply - 4), nounderSupplement);
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).ownerOf(totalSupply - 3), nounderSupplement2);
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).ownerOf(totalSupply - 2), nounderSolo);
        
        address firstDelegate = propLot.getDelegateAddress(1);
        assertTrue(firstDelegate.code.length > 0);
        assertTrue(firstDelegate == propLot.simulateCreate2(bytes32(uint256(1)),  propLot.__creationCodeHash()));

        uint256 nextDelegateId = propLot.getNextDelegateId();
        assertEq(nextDelegateId, 2);

        uint256 minRequiredVotesExpected = nounsGovernorProxy.proposalThreshold() + 1;
        (uint256 incompleteDelegateId, uint256 minRequiredVotes) = propLot.getDelegateIdByType(true);
        assertEq(minRequiredVotesExpected, minRequiredVotes);
        assertEq(incompleteDelegateId, 1);

        uint256 numCheckpoints = nounsTokenHarness.numCheckpoints(nounderSupplement);
        assertEq(numCheckpoints, 1);

        assertEq(proposals.length, 0);
    }

    function test_getDelegateAddress(uint8 fuzzIterations) public {
        vm.assume(fuzzIterations < type(uint16).max - 1);
        for (uint16 i; i < fuzzIterations; ++i) {
            // setup includes a call to `createDelegate()` so next delegate ID is already incremented
            uint16 fuzzDelegateId = i + 2;
            address resultDelegate = propLot.getDelegateAddress(fuzzDelegateId);
            
            address actualDelegate = propLot.createDelegate();
            assertEq(resultDelegate, actualDelegate);
        }
    }

    function test_revertGetDelegateAddressInvalidDelegateId() public {
        bytes memory err = abi.encodeWithSelector(IPropLot.InvalidDelegateId.selector, 0);
        vm.expectRevert(err);
        propLot.getDelegateAddress(0);
    }

    function test_createDelegate(uint8 fuzzIterations) public {
        uint256 startDelegateId = propLot.getNextDelegateId();
        assertEq(startDelegateId, 2);

        for (uint16 i; i < fuzzIterations; ++i) {
            uint256 fuzzDelegateId = startDelegateId + i;
            address resultDelegate = propLot.getDelegateAddress(fuzzDelegateId);
            assertTrue(resultDelegate.code.length == 0);

            vm.expectEmit(true, false, false, false);
            emit DelegateCreated(resultDelegate, fuzzDelegateId);
            address createdDelegate = propLot.createDelegate();
            assertTrue(resultDelegate.code.length != 0);
            assertEq(resultDelegate, createdDelegate);
            
            // assert next delegate ID was incremented
            uint256 nextDelegateId = propLot.getNextDelegateId();
            assertEq(fuzzDelegateId + 1, nextDelegateId);
        }
    }

    function test_simulateCreate2(uint8 fuzzIterations) public {
        address firstDelegate = propLot.getDelegateAddress(1);
        assertTrue(firstDelegate.code.length != 0);
        assertTrue(firstDelegate == propLot.simulateCreate2(bytes32(uint256(1)),  propLot.__creationCodeHash()));
        
        uint256 startDelegateId = propLot.getNextDelegateId();

        for (uint256 i; i < fuzzIterations; ++i) {
            uint256 fuzzDelegateId = startDelegateId + i;
            address expectedDelegate = propLot.simulateCreate2(bytes32(fuzzDelegateId), propLot.__creationCodeHash());
            address createdDelegate = propLot.createDelegate();
            assertEq(expectedDelegate, createdDelegate);
            assertEq(expectedDelegate, propLot.getDelegateAddress(fuzzDelegateId));
        }
    }

    function test_registerDelegationSupplement() public {
        // roll forward one block so `numCheckpoints` is updated when delegating
        vm.roll(block.number + 1);

        address selfDelegate = nounsTokenHarness.delegates(nounderSupplement);
        assertEq(selfDelegate, nounderSupplement);
        uint256 startCheckpoints = nounsTokenHarness.numCheckpoints(nounderSupplement);
        assertEq(startCheckpoints, 1);
        uint256 votingPower = nounsTokenHarness.votesToDelegate(nounderSupplement);
        assertEq(votingPower, 1);

        (uint256 delegateId, uint256 minRequiredVotes) = propLot.getDelegateIdByType(true);
        assertEq(delegateId, 1);
        assertEq(minRequiredVotes, 2);

        address delegate = propLot.getDelegateAddress(delegateId);
        (address suitableDelegate, ) = propLot.getSuitableDelegateFor(nounderSupplement);
        assertEq(suitableDelegate, delegate);

        // perform external delegation to relevant delegate
        vm.prank(nounderSupplement);
        nounsTokenHarness.delegate(delegate);

        address delegated = nounsTokenHarness.delegates(nounderSupplement);
        assertEq(delegated, delegate);

        uint256 nextCheckpoints = nounsTokenHarness.numCheckpoints(nounderSupplement);
        assertEq(nextCheckpoints, startCheckpoints + 1);
        uint256 nextDelegateId = propLot.getNextDelegateId();

        IPropLot.Delegation memory delegation = IPropLot.Delegation(
            nounderSupplement, 
            uint32(block.number),
            uint32(nextCheckpoints),
            uint16(votingPower),
            uint16(delegateId)
        );
        vm.expectEmit(true, false, false, false);
        emit DelegationRegistered(delegation);
        vm.prank(nounderSupplement);
        propLot.registerDelegation(nounderSupplement, delegateId);

        // assert no new delegate was created
        assertEq(nextDelegateId, propLot.getNextDelegateId());

        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();
        assertEq(optimisticDelegations.length, 1);
        assertEq(optimisticDelegations[0].delegator, nounderSupplement);
        assertEq(optimisticDelegations[0].blockDelegated, uint32(block.number));
        assertEq(optimisticDelegations[0].numCheckpointsSnapshot, uint32(nextCheckpoints));
        assertEq(optimisticDelegations[0].votingPower, uint16(votingPower));
        assertEq(optimisticDelegations[0].delegateId, uint16(delegateId));

        (uint256 existingSupplementId, ) = propLot.getDelegateIdByType(true);
        assertEq(existingSupplementId, delegateId);

        (uint256 expectNewDelegateId, ) = propLot.getDelegateIdByType(false);
        assertEq(expectNewDelegateId, nextDelegateId);

        // the delegation should not register as an eligible proposer
        (, uint256[] memory allEligibleProposerIds) = propLot.getAllEligibleProposerDelegates();
        assertEq(allEligibleProposerIds.length, 0);
        // the partial delegation should be found
        (, address[] memory allPartialDelegates) = propLot.getAllPartialDelegates();
        assertEq(allPartialDelegates.length, 1);
        assertEq(allPartialDelegates[0], delegate);

        // proposal cannot pushed using the first delegate after 1 block as it requires another vote
        vm.roll(block.number + 1);
        vm.prank(address(propLot));
        bytes memory err = abi.encodeWithSignature("VotesBelowProposalThreshold()");
        vm.expectRevert(err);
        Delegate(delegate).pushProposal(INounsDAOLogicV3(address(nounsGovernorProxy)), txs, description);
    }

    function test_registerDelegationSolo() public {
        // roll forward one block so `numCheckpoints` is updated when delegating
        vm.roll(block.number + 1);

        address selfDelegate = nounsTokenHarness.delegates(nounderSolo);
        assertEq(selfDelegate, nounderSolo);
        uint256 startCheckpoints = nounsTokenHarness.numCheckpoints(nounderSolo);
        assertEq(startCheckpoints, 1);
        
        uint256 votingPower = nounsTokenHarness.votesToDelegate(nounderSolo);
        uint256 minRequiredVotes = nounsGovernorProxy.proposalThreshold() + 1;
        assertEq(votingPower, minRequiredVotes);

        (uint256 delegateId, ) = propLot.getDelegateIdByType(true);
        assertEq(delegateId, 1);
        address delegate = propLot.getDelegateAddress(delegateId);
        (address suitableDelegate, ) = propLot.getSuitableDelegateFor(nounderSolo);
        assertEq(suitableDelegate, delegate);

        // perform external delegation to relevant delegate
        vm.prank(nounderSolo);
        nounsTokenHarness.delegate(delegate);

        address delegated = nounsTokenHarness.delegates(nounderSolo);
        assertEq(delegated, delegate);

        uint256 nextCheckpoints = nounsTokenHarness.numCheckpoints(nounderSolo);
        assertEq(nextCheckpoints, startCheckpoints + 1);
        uint256 nextDelegateId = propLot.getNextDelegateId();
        assertEq(nextDelegateId, 2);

        IPropLot.Delegation memory delegation = IPropLot.Delegation(
            nounderSolo, 
            uint32(block.number),
            uint32(nextCheckpoints),
            uint16(votingPower),
            uint16(delegateId)
        );
        vm.expectEmit(true, false, false, false);
        emit DelegationRegistered(delegation);
        vm.prank(nounderSolo);
        propLot.registerDelegation(nounderSolo, delegateId);

        // assert no new delegate was created
        assertEq(nextDelegateId, propLot.getNextDelegateId());

        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();
        assertEq(optimisticDelegations.length, 1);
        assertEq(optimisticDelegations[0].delegator, nounderSolo);
        assertEq(optimisticDelegations[0].blockDelegated, uint32(block.number));
        assertEq(optimisticDelegations[0].numCheckpointsSnapshot, uint32(nextCheckpoints));
        assertEq(optimisticDelegations[0].votingPower, uint16(votingPower));
        assertEq(optimisticDelegations[0].delegateId, uint16(delegateId));

        // delegateId 1 is saturated so getDelegateIdByType should always return nextDelegateId
        (, uint256 returnedSoloId) = propLot.getDelegateIdByType(true);
        assertEq(returnedSoloId, nextDelegateId);
        (, uint256 returnedSupplementDelegateId) = propLot.getDelegateIdByType(false);
        assertEq(returnedSupplementDelegateId, nextDelegateId);

        // the delegation should register as an eligible proposer
        (, uint256[] memory allEligibleProposerIds) = propLot.getAllEligibleProposerDelegates();
        assertEq(allEligibleProposerIds.length, 1);
        assertEq(propLot.getDelegateAddress(allEligibleProposerIds[0]), delegate);
        // no partial delegates should be found
        (, address[] memory allPartialDelegates) = propLot.getAllPartialDelegates();
        assertEq(allPartialDelegates.length, 0);

        // proposal can now be pushed using the first delegate after 1 block (simple POC)
        vm.roll(block.number + 1);
        vm.prank(address(propLot));
        Delegate(delegate).pushProposal(INounsDAOLogicV3(address(nounsGovernorProxy)), txs, description);
    }

    function test_revertPushProposalNotIdeaTokenHub() public {
        bytes memory err = abi.encodeWithSelector(IPropLot.OnlyIdeaContract.selector);
        vm.expectRevert(err);
        propLot.pushProposals(proposals);
    }

    function test_revertPushProposalNotPropLot() public {
        Delegate firstDelegate = Delegate(propLot.getDelegateAddress(1));
        
        bytes memory err = abi.encodeWithSelector(Delegate.NotPropLotCore.selector, address(this));
        vm.expectRevert(err);
        firstDelegate.pushProposal(INounsDAOLogicV3(address(nounsGovernorProxy)), txs, description);
    }

    function test_pushProposals(uint8 numFullDelegations, uint8 numSupplementaryDelegations) public {
        vm.assume(numFullDelegations != 0 || numSupplementaryDelegations > 1);

        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            // mint `minRequiredVotes / 2` to new nounder and delegate
            address currentSupplementaryNounder = _createNounderEOA(i);
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 notMinRequiredVotes = minRequiredVotes / 2;
            for (uint256 j; j < notMinRequiredVotes; ++j) {
                NounsTokenHarness(address(nounsTokenHarness)).mintTo(currentSupplementaryNounder);
            }
            uint256 returnedSupplementaryBalance = NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
            assertEq(returnedSupplementaryBalance, notMinRequiredVotes);
            
            (uint256 delegateId, ) = propLot.getDelegateIdByType(true);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentSupplementaryNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentSupplementaryNounder, delegateId);
            vm.stopPrank();
        }

        for (uint256 k; k < numFullDelegations; ++k) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `k` to get new addresses
            address currentFullNounder = _createNounderEOA(k + numSupplementaryDelegations);
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();

            for (uint256 l; l < minRequiredVotes; ++l) {
                NounsTokenHarness(address(nounsTokenHarness)).mintTo(currentFullNounder);
            }
            uint256 returnedFullBalance = NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, minRequiredVotes);

            (uint256 delegateId, ) = propLot.getDelegateIdByType(false);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentFullNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentFullNounder, delegateId);
            vm.stopPrank();
        }

        // populate proposals storage array only once `numEligibleProposers` is known
        (, uint256 numEligibleProposers) = propLot.numEligibleProposerDelegates();
        for (uint256 m; m < numEligibleProposers; ++m) {
            proposals.push(IPropLot.Proposal(txs, description));
        }

        // push proposal to Nouns ecosystem
        vm.roll(block.number + 1);
        vm.prank(address(ideaTokenHub));
        propLot.pushProposals(proposals);
    }

    function test_getDelegateIdByType(uint8 numSupplementaryDelegates, uint8 numFullDelegates) public {
        vm.assume(numSupplementaryDelegates != 0 && numFullDelegates != 0);
        uint256 totalDels = uint256(numSupplementaryDelegates) + uint256(numFullDelegates);
        uint256 delCounter;
        while (delCounter < totalDels) {
            uint256 supplementaryCounter;
            // make delegations in pseudorandom order using sufficiently entropic hash            
            uint256 entropicHash = uint256(keccak256(abi.encode(delCounter)));
            bool supplementaryIter = entropicHash % 2 == 0 ? true : false;
            if (supplementaryIter && supplementaryCounter < numSupplementaryDelegates) {
                // perform supplementary delegation
                address currentSupplementaryNounder = _createNounderEOA(delCounter);
                uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
                uint256 amt = minRequiredVotes / 2;
                
                // mint `amt < minRequiredVotes` to new nounder EOA and delegate
                NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);
                uint256 returnedSupplementaryBalance = NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
                assertEq(returnedSupplementaryBalance, amt);
                
                (uint256 delegateId, ) = propLot.getDelegateIdByType(true);
                address delegate = propLot.getDelegateAddress(delegateId);
                
                vm.startPrank(currentSupplementaryNounder);
                nounsTokenHarness.delegate(delegate);
                propLot.registerDelegation(currentSupplementaryNounder, delegateId);
                vm.stopPrank();

                ++supplementaryCounter;
            } else {
                // perform full delegation
                address currentFullNounder = _createNounderEOA(delCounter);
                uint256 amt = propLot.getCurrentMinRequiredVotes();
                
                // mint `amt == minRequiredVotes` to new nounder EOA and delegate
                NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);
                uint256 returnedFullBalance = NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentFullNounder);
                assertEq(returnedFullBalance, amt);
                
                (uint256 delegateId, ) = propLot.getDelegateIdByType(false);
                address delegate = propLot.getDelegateAddress(delegateId);
                
                vm.startPrank(currentFullNounder);
                nounsTokenHarness.delegate(delegate);
                propLot.registerDelegation(currentFullNounder, delegateId);
                vm.stopPrank();
            }

            ++delCounter;
        }

        // assert that delegate returned by getDelegateIdByType has votingPower < or > minRequiredVotes
        (uint256 supplementId, uint256 newMinRequiredVotes) = propLot.getDelegateIdByType(true);
        (uint256 fullId, ) = propLot.getDelegateIdByType(false);
        
        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();
        bool supplementMatchFound;
        bool fullMatchFound;
        uint256 nextDelegateId = propLot.getNextDelegateId();
        for (uint256 j; j < optimisticDelegations.length; ++j) {
            if (optimisticDelegations[j].delegateId == fullId || fullId == nextDelegateId) {
                fullMatchFound = true;
            }
            if (optimisticDelegations[j].delegateId == supplementId || supplementId == nextDelegateId) {
                supplementMatchFound = true;
            }
        }

        assertTrue(supplementMatchFound);
        assertTrue(fullMatchFound);

        address supplement = propLot.getDelegateAddress(supplementId);
        uint256 supplementVotes = nounsTokenHarness.getCurrentVotes(supplement);
        // if the `supplementId` returned by `getDelegateIdByType()` is the next delegate id, that Delegate address
        // will have 0 votes, thus the `votingPower` assert is only necessary if a partially saturated Delegate ID was returned
        if (supplementId != nextDelegateId) {
            assertTrue(supplementVotes < newMinRequiredVotes);
        } else {
            assertEq(supplementVotes, 0);
        }

        address full = propLot.getDelegateAddress(fullId);
        uint256 fullVotes = nounsTokenHarness.getCurrentVotes(full);
        // if the `fullId` returned by `getDelegateIdByType()` is the next delegate id, that Delegate address
        // will have 0 votes, thus the `votingPower` assert is only necessary if a totally unsaturated Delegate ID was returned
        if (fullId != nextDelegateId) {
            assertTrue(fullVotes >= newMinRequiredVotes);
        } else {
            assertEq(fullVotes, 0);
        }
    }
    

    //todo try calling `setOptimisticDelegation()` and then immediately redelegate back to self in same block
    // to test internal state and make sure the falsified Delegation is cleared upon settlement
    //function test_registerDelegationRedelegateSameBlock()
    //function test_pushProposalsRemoveRogueDelegators()
    //function test_delegateBySig()
    //function test_proposalThresholdIncrease()
    //function test_disqualifiedDelegationIndices()
    //function test_inspectCheckpoints
    //function test_isEligibleProposalState

    function test_deleteDelegations(uint8 numSupplementaryDelegations, uint8 numFullDelegations, uint8 numDeletions) public {
        vm.assume(numSupplementaryDelegations > 0 || numFullDelegations > 0);
        uint256 totalDelegations = uint256(numSupplementaryDelegations) + uint256(numFullDelegations);
        vm.assume(numDeletions > 0 && numDeletions < totalDelegations);

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // make fuzzed supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);
            // mint `minRequiredVotes / 2` to new nounder and delegate
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            uint256 returnedSupplementaryBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
            assertEq(returnedSupplementaryBalance, amt);
            
            (uint256 delegateId, ) = propLot.getDelegateIdByType(true);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentSupplementaryNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentSupplementaryNounder, delegateId);
            vm.stopPrank();

            // simulate time passing
            vm.roll(block.number + 200);
            eoa = !eoa;
        }

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = propLot.getCurrentMinRequiredVotes();
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            (uint256 delegateId, ) = propLot.getDelegateIdByType(false);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentFullNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentFullNounder, delegateId);
            vm.stopPrank();

            // simulate time passing
            vm.roll(block.number + 200);
            eoa = !eoa;
        }

        // used for assertions
        IPropLot.Delegation[] memory arrayBeforeDeletion = propLot.getOptimisticDelegations();

        // populate pseudo-random set of indices to delete without regard for disqualification
        uint256[] memory indicesToDelete = new uint256[](numDeletions);
        for (uint256 k; k < numDeletions; ++k) {
            // first initialize array with ordered indices
            indicesToDelete[k] = k;
        }

        // then perform Fisher-Yates shuffle on `indicesToDelete` to create a random permutation of [0:numDeletions]
        for (uint256 l = indicesToDelete.length - 1; l > 0; l--) {
            uint256 m = uint256(keccak256(abi.encode(l))) % (l + 1);
            // swap indicesToDelete[i] and indicesToDelete[j]
            (indicesToDelete[l], indicesToDelete[m]) = (indicesToDelete[m], indicesToDelete[l]);
        }

        // used to assert delegations were deleted
        IPropLot.Delegation[] memory delegationsToDelete = new IPropLot.Delegation[](numDeletions);
        for (uint256 z; z < numDeletions; ++z) {
            delegationsToDelete[z] = arrayBeforeDeletion[indicesToDelete[z]];
        }

        // assert all events emitted properly
        for (uint256 n; n < indicesToDelete.length; ++n) {
            vm.expectEmit(true, true, true, false);
            emit IPropLot.DelegationDeleted(arrayBeforeDeletion[indicesToDelete[n]]);
        }

        // delete fuzzed number of delegations
        propLot.deleteDelegations(indicesToDelete);

        // asserts
        IPropLot.Delegation[] memory arrayAfterDeletion = propLot.getOptimisticDelegations();
        assertEq(arrayAfterDeletion.length, arrayBeforeDeletion.length - numDeletions);

        // since delegator addresses are derived from unique privkeys/create2 salts, they uniquely identify each delegation 
        for (uint256 o; o < delegationsToDelete.length; ++o) {
            address currentDelegator = delegationsToDelete[o].delegator;
            for (uint256 p; p < arrayAfterDeletion.length; ++p) {
                // assert deleted deletion no longer exists
                assertTrue(currentDelegator != arrayAfterDeletion[p].delegator);
            }
        }
    }

    //function test_deleteDelegationsZeroMembers()
    //function test_computeNounsDelegationDigest
    //function test_findDelegateId
    // function test_findProposerDelegate
}