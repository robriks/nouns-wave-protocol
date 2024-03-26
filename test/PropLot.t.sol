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

    struct DelegatorInfo {
        address nounder;
        uint256[] ownedTokenIds;
    }

    string uri;
    NounsDAOV3Proposals.ProposalTxs txs;
    string description;
    // for fuzzing purposes, should remain empty until `numEligibleProposers` is known
    IPropLot.Proposal[] proposals;
    DelegatorInfo[] supplementaryDelegatorsTemp;
    DelegatorInfo[] fullDelegatorsTemp;
    DelegatorInfo[] agnosticDelegatorsTemp;

    uint256 nounderSupplementPK;
    uint256 nounderSupplement2PK;
    uint256 nounderSoloPK;
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
        nounderSupplementPK = 0xc0ffeebabe;
        nounderSupplement = vm.addr(nounderSupplementPK);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSupplement), 0);
        NounsTokenHarness(address(nounsTokenHarness)).mintTo(nounderSupplement);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSupplement), 1);
        
        // mint 1 token to nounderSupplement2
        nounderSupplement2PK = 0xc0ffeebae;
        nounderSupplement2 = vm.addr(nounderSupplement2PK);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSupplement2), 0);
        NounsTokenHarness(address(nounsTokenHarness)).mintTo(nounderSupplement2);
        assertEq(nounsTokenHarness.numCheckpoints(nounderSupplement2), 1);
        
        // mint 2 tokens to nounderSolo
        nounderSoloPK = 0xbeefEbabe;
        nounderSolo = vm.addr(nounderSoloPK);
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
        uint256 minRequiredVotesReturned = propLot.getCurrentMinRequiredVotes();
        assertEq(minRequiredVotesExpected, minRequiredVotesReturned);
        uint256 incompleteDelegateId = propLot.getDelegateIdByType(minRequiredVotesReturned, true);
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

        uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
        uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, true);
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
            uint16(votingPower),
            uint16(delegateId)
        );
        vm.expectEmit(true, false, false, false);
        emit DelegationRegistered(delegation);
        vm.prank(nounderSupplement);
        propLot.registerDelegation(nounderSupplement, delegateId, votingPower);

        // assert no new delegate was created
        assertEq(nextDelegateId, propLot.getNextDelegateId());

        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();
        assertEq(optimisticDelegations.length, 1);
        assertEq(optimisticDelegations[0].delegator, nounderSupplement);
        assertEq(optimisticDelegations[0].blockDelegated, uint32(block.number));
        assertEq(optimisticDelegations[0].votingPower, uint16(votingPower));
        assertEq(optimisticDelegations[0].delegateId, uint16(delegateId));

        uint256 existingSupplementId = propLot.getDelegateIdByType(minRequiredVotes, true);
        assertEq(existingSupplementId, delegateId);

        uint256 expectNewDelegateId = propLot.getDelegateIdByType(minRequiredVotes, false);
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

        uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, true);
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
            uint16(votingPower),
            uint16(delegateId)
        );
        vm.expectEmit(true, false, false, false);
        emit DelegationRegistered(delegation);
        vm.prank(nounderSolo);
        propLot.registerDelegation(nounderSolo, delegateId, votingPower);

        // assert no new delegate was created
        assertEq(nextDelegateId, propLot.getNextDelegateId());

        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();
        assertEq(optimisticDelegations.length, 1);
        assertEq(optimisticDelegations[0].delegator, nounderSolo);
        assertEq(optimisticDelegations[0].blockDelegated, uint32(block.number));
        assertEq(optimisticDelegations[0].votingPower, uint16(votingPower));
        assertEq(optimisticDelegations[0].delegateId, uint16(delegateId));

        // delegateId 1 is saturated so getDelegateIdByType should always return nextDelegateId
        uint256 returnedSoloId = propLot.getDelegateIdByType(minRequiredVotes, true);
        assertEq(returnedSoloId, nextDelegateId);
        uint256 returnedSupplementDelegateId = propLot.getDelegateIdByType(minRequiredVotes, false);
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

    function test_delegateBySig(uint8 numSigners, uint8 fuzzDelegateId, uint8 expiryOffset) public {
        vm.assume(fuzzDelegateId != 0); // filter invalid delegate IDs

        for (uint256 i; i < numSigners; ++i) {
            address signer = _createNounderEOA(i);
            uint256 privKey = i + 1; // under the hood, `_createNounderEOA` uses incremented value as private key

            // signer does not hold Nouns tokens but in this case it does not matter
            address delegate = propLot.getDelegateAddress(fuzzDelegateId);
            bytes32 nounsDomainSeparator = keccak256(abi.encode(
                nounsTokenHarness.DOMAIN_TYPEHASH(), 
                keccak256(bytes(nounsTokenHarness.name())), 
                block.chainid, 
                address(nounsTokenHarness)
            ));

            uint256 nonce = nounsTokenHarness.nonces(signer);
            uint256 expiry = block.timestamp + expiryOffset;
            bytes32 structHash = keccak256(
                abi.encode(nounsTokenHarness.DELEGATION_TYPEHASH(), delegate, nonce, expiry)
            );
            
            // construct digest manually and check it against PropLot Core's returned value
            bytes32 digest = keccak256(abi.encodePacked('\x19\x01', nounsDomainSeparator, structHash));
            bytes32 returnedDigest = propLot.computeNounsDelegationDigest(signer, fuzzDelegateId, expiry);
            assertEq(digest, returnedDigest);
            
            // perform call directly to Nouns token's `delegateBySig` func with signed digest to ensure it is usable
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
            vm.prank(signer);
            nounsTokenHarness.delegateBySig(delegate, nonce, expiry, v, r, s);
            assertEq(nounsTokenHarness.delegates(signer), delegate);
        }
    }

    function test_pushProposals(uint8 numFullDelegations, uint8 numSupplementaryDelegations) public {
        vm.assume(numFullDelegations != 0 || numSupplementaryDelegations > 1);
        delete proposals;

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
            
            uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, true);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentSupplementaryNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentSupplementaryNounder, delegateId, notMinRequiredVotes);
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

            uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, false);
            address delegate = propLot.getDelegateAddress(delegateId);
            
            vm.startPrank(currentFullNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentFullNounder, delegateId, returnedFullBalance);
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
        (IPropLot.Delegation[] memory validDels, uint256[] memory proposalIds) = propLot.pushProposals(proposals);
        
        // disqualifications out of scope for this test so there are none
        assertEq(validDels.length, uint256(numFullDelegations) + uint256(numSupplementaryDelegations));
        assertEq(proposalIds.length, numEligibleProposers);
    }

    function test_pushProposalsRemoveRogueDelegators(uint8 numSupplementaryDelegations, uint8 numFullDelegations) public {
        // half of all delegations will be disqualified so require either 3 supplementary or 2 full delegations at minimum
        vm.assume(numSupplementaryDelegations > 2 || numFullDelegations > 1);
        delete supplementaryDelegatorsTemp;
        delete fullDelegatorsTemp;
        delete proposals;

        // disqualify half of total delegations
        uint256 numDisqualifications = (uint256(numSupplementaryDelegations) + uint256(numFullDelegations)) / 2;

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // make fuzzed supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);

            // mint `minRequiredVotes / 2` to new nounder and delegate
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;

            // populate temporary storage arrays with delegator addresses and `tokenIds` to be minted
            uint256[] memory tokenIds = new uint256[](amt);
            for (uint256 x; x < amt; ++x) {
                uint256 startId = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
                tokenIds[x] = startId + x;
            }

            // mint the tokens
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            DelegatorInfo memory info = DelegatorInfo(currentSupplementaryNounder, tokenIds);
            agnosticDelegatorsTemp.push(info);

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

        // assert `agnosticDelegatorsTemp` array was populated correctly
        assertEq(agnosticDelegatorsTemp.length, numSupplementaryDelegations);

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = propLot.getCurrentMinRequiredVotes();

            // populate temporary storage arrays with delegator addresses and `tokenIds` to be minted
            uint256[] memory tokenIds = new uint256[](amt);
            for (uint256 x; x < amt; ++x) {
                uint256 startId = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
                tokenIds[x] = startId + x;
            }

            // mint the tokens
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            DelegatorInfo memory info = DelegatorInfo(currentFullNounder, tokenIds);
            agnosticDelegatorsTemp.push(info);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
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

        // assert `fullDelegatorsTemp` array was populated correctly
        assertEq(agnosticDelegatorsTemp.length, uint256(numSupplementaryDelegations) + uint256(numFullDelegations));

        // construct `indiciesToDisqualify` array
        bool delegateOrTransfer;
        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();

        uint256[] memory unTruncatedIndiciesToDisqualify = new uint256[](optimisticDelegations.length);
        // populate array with indices
        for (uint256 z; z < unTruncatedIndiciesToDisqualify.length; ++z) unTruncatedIndiciesToDisqualify[z] = z;
        
        // perform Fisher-Yates shuffle on `optimisticDelegations` indices to create a random permutation
        for (uint256 k; k < optimisticDelegations.length; k++) {
            uint256 remaining = optimisticDelegations.length - k;
            uint256 l = uint256(keccak256(abi.encode(k))) % remaining + k;
            // swap unTruncatedIndiciesToDisqualify[k] and unTruncatedIndiciesToDisqualify[l]
            (unTruncatedIndiciesToDisqualify[k], unTruncatedIndiciesToDisqualify[l]) = (unTruncatedIndiciesToDisqualify[l], unTruncatedIndiciesToDisqualify[k]);
        }

        uint256[] memory indiciesToDisqualify = new uint256[](numDisqualifications);
        console2.logUint(numDisqualifications);
        console2.logUint(optimisticDelegations.length);
        // then truncate resulting shuffled array to obtain randomized array of indices to delete
        for (uint256 m; m < numDisqualifications; ++m) {
            // populate expected return array
            indiciesToDisqualify[m] = unTruncatedIndiciesToDisqualify[m];
            
            // perform disqualifications
            address currentDelegator = optimisticDelegations[unTruncatedIndiciesToDisqualify[m]].delegator;
            vm.startPrank(currentDelegator);
            if (delegateOrTransfer) {
                // disqualify via delegation
                nounsTokenHarness.delegate(address(0x69));
            } else { // disqualify via transfer
                uint256 index;
                // find delegator index in `agnosticDelegatorsTemp`
                for (uint256 n; n < agnosticDelegatorsTemp.length; ++n) {
                    if (agnosticDelegatorsTemp[n].nounder == currentDelegator) index = n;
                }

                DelegatorInfo storage info = agnosticDelegatorsTemp[index];
                assertEq(info.nounder, currentDelegator); // sanity check

                uint256 numTransfers = uint256(keccak256(abi.encode(m))) % info.ownedTokenIds.length + 1; 
                for (uint256 o; o < numTransfers; ++o) {
                    uint256 tokenId = info.ownedTokenIds[o];
                    NounsTokenHarness(address(nounsTokenHarness)).transferFrom(currentDelegator, address(0x69), tokenId);
                }
            }
            vm.stopPrank();

            delegateOrTransfer = !delegateOrTransfer;
        }

        uint256[] memory returnedDisqualifiedIndices = propLot.disqualifiedDelegationIndices();
        assertEq(returnedDisqualifiedIndices.length, indiciesToDisqualify.length);

        // assert all members of `indiciesToDisqualify` are present in `returnedDisqualifiedIndices`
        for (uint256 o; o < indiciesToDisqualify.length; ++o) {
            bool matchFound;
            for (uint256 p; p < returnedDisqualifiedIndices.length; ++p) {
                if (returnedDisqualifiedIndices[p] == indiciesToDisqualify[o]) matchFound = true;
            }
            
            assertTrue(matchFound);
        }

        // populate proposals storage array only once `numEligibleProposers` is known
        (, uint256 numEligibleProposers) = propLot.numEligibleProposerDelegates();
        for (uint256 m; m < numEligibleProposers; ++m) {
            proposals.push(IPropLot.Proposal(txs, description));
        }

        // push proposal to Nouns ecosystem
        vm.roll(block.number + 1);
        vm.prank(address(ideaTokenHub));
        (IPropLot.Delegation[] memory validDels, uint256[] memory proposalIds) = propLot.pushProposals(proposals);
        
        // disqualifications out of scope for this test so there are none
        uint256 numExpectedProposals = uint256(numFullDelegations) + uint256(numSupplementaryDelegations) - numDisqualifications;
        assertEq(validDels.length, numExpectedProposals);
        assertEq(proposalIds.length, numEligibleProposers);
    }

    function test_revertPushProposalsNotIdeaTokenHub() public {
        bytes memory err = abi.encodeWithSelector(IPropLot.OnlyIdeaContract.selector);
        vm.expectRevert(err);
        propLot.pushProposals(proposals);
    }

    function test_revertPushProposalsInsufficientDelegations() public {
        delete proposals;

        bytes memory err = abi.encodeWithSelector(IPropLot.InsufficientDelegations.selector);
        vm.prank(address(ideaTokenHub));
        vm.expectRevert(err);
        propLot.pushProposals(proposals);
    }

    function test_revertPushProposalNotPropLot() public {
        Delegate firstDelegate = Delegate(propLot.getDelegateAddress(1));
        
        bytes memory err = abi.encodeWithSelector(Delegate.NotPropLotCore.selector, address(this));
        vm.expectRevert(err);
        firstDelegate.pushProposal(INounsDAOLogicV3(address(nounsGovernorProxy)), txs, description);
    }

    function test_getDelegateIdByType(uint8 numSupplementaryDelegates, uint8 numFullDelegates) public {
        vm.assume(numSupplementaryDelegates != 0 && numFullDelegates != 0);
        
        uint256 minRequiredVotes;
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
                minRequiredVotes = propLot.getCurrentMinRequiredVotes();
                uint256 amt = minRequiredVotes / 2;
                
                // mint `amt < minRequiredVotes` to new nounder EOA and delegate
                NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);
                uint256 returnedSupplementaryBalance = NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
                assertEq(returnedSupplementaryBalance, amt);
                
                uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, true);
                address delegate = propLot.getDelegateAddress(delegateId);
                
                vm.startPrank(currentSupplementaryNounder);
                nounsTokenHarness.delegate(delegate);
                propLot.registerDelegation(currentSupplementaryNounder, delegateId, amt);
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
                
                minRequiredVotes = propLot.getCurrentMinRequiredVotes();
                uint256 delegateId = propLot.getDelegateIdByType(minRequiredVotes, false);
                address delegate = propLot.getDelegateAddress(delegateId);
                
                vm.startPrank(currentFullNounder);
                nounsTokenHarness.delegate(delegate);
                propLot.registerDelegation(currentFullNounder, delegateId, amt);
                vm.stopPrank();
            }

            ++delCounter;
        }

        // assert that delegate returned by getDelegateIdByType has votingPower < or > minRequiredVotes
        minRequiredVotes = propLot.getCurrentMinRequiredVotes();
        uint256 supplementId = propLot.getDelegateIdByType(minRequiredVotes, true);
        uint256 fullId = propLot.getDelegateIdByType(minRequiredVotes, false);
        
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
            assertTrue(supplementVotes < minRequiredVotes);
        } else {
            assertEq(supplementVotes, 0);
        }

        address full = propLot.getDelegateAddress(fullId);
        uint256 fullVotes = nounsTokenHarness.getCurrentVotes(full);
        // if the `fullId` returned by `getDelegateIdByType()` is the next delegate id, that Delegate address
        // will have 0 votes, thus the `votingPower` assert is only necessary if a totally unsaturated Delegate ID was returned
        if (fullId != nextDelegateId) {
            assertTrue(fullVotes >= minRequiredVotes);
        } else {
            assertEq(fullVotes, 0);
        }
    }

    function test_isDisqualifiedRedelegate(uint8 numSupplementaryDelegations, uint8 numFullDelegations, uint8 numSupplementaryDisqualifications, uint8 numFullDisqualifications) public {
        vm.assume(numSupplementaryDelegations > 0 || numFullDelegations > 0);
        vm.assume(numSupplementaryDisqualifications < numSupplementaryDelegations);
        vm.assume(numFullDisqualifications < numFullDelegations);

        delete supplementaryDelegatorsTemp;
        delete fullDelegatorsTemp;

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // make fuzzed supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);

            // mint `minRequiredVotes / 2` to new nounder and delegate
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;
            
            // populate temporary storage arrays with delegator addresses and `tokenIds` to be minted
            uint256[] memory tokenIds = new uint256[](amt);
            for (uint256 x; x < amt; ++x) {
                uint256 startId = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
                tokenIds[x] = startId + x;
            }

            // mint the tokens
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            DelegatorInfo memory info = DelegatorInfo(currentSupplementaryNounder, tokenIds);
            supplementaryDelegatorsTemp.push(info);

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

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = propLot.getCurrentMinRequiredVotes();
            
            // populate temporary storage arrays with delegator addresses and `tokenIds` to be minted
            uint256[] memory tokenIds = new uint256[](amt);
            for (uint256 x; x < amt; ++x) {
                uint256 startId = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
                tokenIds[x] = startId + x;
            }

            // mint the tokens
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            DelegatorInfo memory info = DelegatorInfo(currentFullNounder, tokenIds);
            fullDelegatorsTemp.push(info);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
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

        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();
        bool redelegateToPropLot; // conditionally have disqualifying users redelegate to protocol
        // prank disqualifying activity
        for (uint256 k; k < numSupplementaryDisqualifications; ++k) {
            address currentDisqualified = supplementaryDelegatorsTemp[k].nounder;
            // sanity check that a delegation exists
            assertTrue(nounsTokenHarness.delegates(currentDisqualified) != currentDisqualified);
            
            vm.prank(currentDisqualified);
            nounsTokenHarness.delegate(currentDisqualified);

            // roll forward a block to update votes
            vm.roll(block.number + 1);
            
            // fetch `isDisqualified()` params
            address originalDelegate;
            uint256 votingPower;
            for (uint256 l; l < optimisticDelegations.length; ++l) {
                if (optimisticDelegations[l].delegator == currentDisqualified) {
                    uint256 originalId = optimisticDelegations[l].delegateId;
                    originalDelegate = propLot.getDelegateAddress(originalId);
                    votingPower = optimisticDelegations[l].votingPower;
                }
            }
            assertTrue(originalDelegate != address(0x0)); // sanity check a match was found

            // flip between compliant and noncompliant behavior
            if (redelegateToPropLot) {
                vm.prank(currentDisqualified);
                nounsTokenHarness.delegate(originalDelegate);

                // roll forward a block to update votes
                vm.roll(block.number + 1);
            }

            bool disqualify = propLot.isDisqualified(currentDisqualified, originalDelegate, votingPower);
            // redelegations are allowed only if Nounder returns registered amount of voting power to registered delegate
            if (redelegateToPropLot) {
                assertFalse(disqualify);
            } else {
                assertTrue(disqualify);
            }

            redelegateToPropLot = !redelegateToPropLot;
        }

        for (uint256 m; m < numFullDisqualifications; ++m) {
            address currentDisqualified = fullDelegatorsTemp[m].nounder;
            // sanity check that a delegation exists
            assertTrue(nounsTokenHarness.delegates(currentDisqualified) != currentDisqualified); 

            vm.prank(currentDisqualified);
            nounsTokenHarness.delegate(currentDisqualified);

            // roll forward a block to update votes
            vm.roll(block.number + 1);
            
            // fetch `isDisqualified()` params
            address originalDelegate;
            uint256 votingPower;
            for (uint256 n; n < optimisticDelegations.length; ++n) {
                if (optimisticDelegations[n].delegator == currentDisqualified) {
                    uint256 originalId = optimisticDelegations[n].delegateId;
                    originalDelegate = propLot.getDelegateAddress(originalId);
                    votingPower = optimisticDelegations[n].votingPower;
                }
            }
            assertTrue(originalDelegate != address(0x0));

            // flip between compliant and noncompliant behavior
            if (redelegateToPropLot) {
                vm.prank(currentDisqualified);
                nounsTokenHarness.delegate(originalDelegate);
                // roll forward a block to update votes
                vm.roll(block.number + 1);
            }
            
            bool disqualify = propLot.isDisqualified(currentDisqualified, originalDelegate, votingPower);
            // redelegations are allowed only if Nounder returns registered amount of voting power to registered delegate
            if (redelegateToPropLot) {
                assertFalse(disqualify);
            } else {
                assertTrue(disqualify);
            }

            redelegateToPropLot = !redelegateToPropLot;
        }
    }

    function test_isDisqualifiedTransfer(uint8 numSupplementaryDelegations, uint8 numFullDelegations, uint8 numSupplementaryDisqualifications, uint8 numFullDisqualifications) public {
        vm.assume(numSupplementaryDelegations > 0 || numFullDelegations > 0);
        vm.assume(numSupplementaryDisqualifications < numSupplementaryDelegations);
        vm.assume(numFullDisqualifications < numFullDelegations);

        delete supplementaryDelegatorsTemp;
        delete fullDelegatorsTemp;

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // make fuzzed supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);

            // mint `minRequiredVotes / 2` to new nounder and delegate
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;

            // populate temporary storage arrays with delegator addresses and `tokenIds` to be minted
            uint256[] memory tokenIds = new uint256[](amt);
            for (uint256 x; x < amt; ++x) {
                uint256 startId = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
                tokenIds[x] = startId + x;
            }

            // mint the tokens
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            DelegatorInfo memory info = DelegatorInfo(currentSupplementaryNounder, tokenIds);
            supplementaryDelegatorsTemp.push(info);

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

        // assert `supplementaryDelegatorsTemp` array was populated correctly
        assertEq(supplementaryDelegatorsTemp.length, numSupplementaryDelegations);

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = propLot.getCurrentMinRequiredVotes();

            // populate temporary storage arrays with delegator addresses and `tokenIds` to be minted
            uint256[] memory tokenIds = new uint256[](amt);
            for (uint256 x; x < amt; ++x) {
                uint256 startId = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
                tokenIds[x] = startId + x;
            }

            // mint the tokens
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            DelegatorInfo memory info = DelegatorInfo(currentFullNounder, tokenIds);
            fullDelegatorsTemp.push(info);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
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

        // assert `fullDelegatorsTemp` array was populated correctly
        assertEq(fullDelegatorsTemp.length, numFullDelegations);

        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();
        bool transferBackToPropLot; // conditionally have disqualifying users transfer back to protocol
        // prank disqualifying activity
        for (uint256 k; k < numSupplementaryDisqualifications; ++k) {
            address currentDisqualified = supplementaryDelegatorsTemp[k].nounder;
            uint256 amt = supplementaryDelegatorsTemp[k].ownedTokenIds.length;
            // sanity check that a delegation exists and that `ownedTokenIds` is populated
            assertTrue(nounsTokenHarness.delegates(currentDisqualified) != currentDisqualified); 
            assertTrue(amt != 0);

            // roll forward a block to update votes
            vm.roll(block.number + 1);

            uint256 pseudoRandomTransferAmt = uint256(keccak256(abi.encode(k))) % amt + 1;
            vm.startPrank(currentDisqualified);
            for (uint256 x; x < pseudoRandomTransferAmt; ++x) {
                uint256 tokenId = supplementaryDelegatorsTemp[k].ownedTokenIds[x];                
                NounsTokenHarness(address(nounsTokenHarness)).transferFrom(currentDisqualified, address(this), tokenId);
                
                // roll forward a block to update votes (checkpoints update only once when transfers are within same block)
                vm.roll(block.number + 1);
            }
            vm.stopPrank();
            
            // fetch `isDisqualified()` params
            address originalDelegate;
            uint256 votingPower;
            for (uint256 l; l < optimisticDelegations.length; ++l) {
                if (optimisticDelegations[l].delegator == currentDisqualified) {
                    uint256 originalId = optimisticDelegations[l].delegateId;
                    originalDelegate = propLot.getDelegateAddress(originalId);
                    votingPower = optimisticDelegations[l].votingPower;
                }
            }

            assertTrue(originalDelegate != address(0x0)); // sanity check a match was found

            // flip between compliant and noncompliant behavior
            if (transferBackToPropLot) {
                for (uint256 x; x < pseudoRandomTransferAmt; ++x) {
                uint256 tokenId = supplementaryDelegatorsTemp[k].ownedTokenIds[x];                
                NounsTokenHarness(address(nounsTokenHarness)).transferFrom(address(this), currentDisqualified, tokenId);
                
                // roll forward a block to update votes (checkpoints update only once when transfers are within same block)
                vm.roll(block.number + 1);
                }
            }

            bool disqualify = propLot.isDisqualified(currentDisqualified, originalDelegate, votingPower);
            // redelegations are allowed only if Nounder returns registered amount of voting power to registered delegate
            if (transferBackToPropLot) {
                assertFalse(disqualify);
            } else {
                assertTrue(disqualify);
            }

            transferBackToPropLot = !transferBackToPropLot;
        }

        for (uint256 m; m < numFullDisqualifications; ++m) {
            address currentDisqualified = fullDelegatorsTemp[m].nounder;
            uint256 amt = fullDelegatorsTemp[m].ownedTokenIds.length;
            // sanity check that a delegation exists and that `ownedTokenIds` is populated
            assertTrue(nounsTokenHarness.delegates(currentDisqualified) != currentDisqualified); 
            assertTrue(amt != 0);

            // roll forward a block to update votes
            vm.roll(block.number + 1);

            uint256 pseudoRandomTransferAmt = uint256(keccak256(abi.encode(m))) % amt + 1;
            vm.startPrank(currentDisqualified);
            for (uint256 x; x < pseudoRandomTransferAmt; ++x) {
                uint256 tokenId = fullDelegatorsTemp[m].ownedTokenIds[x];
                NounsTokenHarness(address(nounsTokenHarness)).transferFrom(currentDisqualified, address(this), tokenId);

                // roll forward a block to update votes (checkpoints update only once when transfers are within same block)
                vm.roll(block.number + 1);
            }
            vm.stopPrank();
            
            // fetch `isDisqualified()` params
            address originalDelegate;
            uint256 votingPower;
            for (uint256 n; n < optimisticDelegations.length; ++n) {
                if (optimisticDelegations[n].delegator == currentDisqualified) {
                    uint256 originalId = optimisticDelegations[n].delegateId;
                    originalDelegate = propLot.getDelegateAddress(originalId);
                    votingPower = optimisticDelegations[n].votingPower;
                }
            }
            assertTrue(originalDelegate != address(0x0));
         
            // flip between compliant and noncompliant behavior
            if (transferBackToPropLot) {
                for (uint256 x; x < pseudoRandomTransferAmt; ++x) {
                uint256 tokenId = fullDelegatorsTemp[m].ownedTokenIds[x];                
                NounsTokenHarness(address(nounsTokenHarness)).transferFrom(address(this), currentDisqualified, tokenId);
                
                // roll forward a block to update votes (checkpoints update only once when transfers are within same block)
                vm.roll(block.number + 1);
                }
            }

            bool disqualify = propLot.isDisqualified(currentDisqualified, originalDelegate, votingPower);
            // redelegations are allowed only if Nounder returns registered amount of voting power to registered delegate
            if (transferBackToPropLot) {
                assertFalse(disqualify);
            } else {
                assertTrue(disqualify);
            }

            transferBackToPropLot = !transferBackToPropLot;
        }
    }

    function test_disqualifiedDelegationIndices(uint8 numSupplementaryDelegations, uint8 numFullDelegations) public {
        vm.assume(numSupplementaryDelegations > 0 || numFullDelegations > 0);
        delete supplementaryDelegatorsTemp;
        delete fullDelegatorsTemp;

        // disqualify half of total delegations
        uint256 numDisqualifications = (uint256(numSupplementaryDelegations) + uint256(numFullDelegations)) / 2;

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // make fuzzed supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);

            // mint `minRequiredVotes / 2` to new nounder and delegate
            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
            uint256 amt = minRequiredVotes / 2;

            // populate temporary storage arrays with delegator addresses and `tokenIds` to be minted
            uint256[] memory tokenIds = new uint256[](amt);
            for (uint256 x; x < amt; ++x) {
                uint256 startId = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
                tokenIds[x] = startId + x;
            }

            // mint the tokens
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);

            DelegatorInfo memory info = DelegatorInfo(currentSupplementaryNounder, tokenIds);
            agnosticDelegatorsTemp.push(info);

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

        // assert `agnosticDelegatorsTemp` array was populated correctly
        assertEq(agnosticDelegatorsTemp.length, numSupplementaryDelegations);

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = propLot.getCurrentMinRequiredVotes();

            // populate temporary storage arrays with delegator addresses and `tokenIds` to be minted
            uint256[] memory tokenIds = new uint256[](amt);
            for (uint256 x; x < amt; ++x) {
                uint256 startId = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
                tokenIds[x] = startId + x;
            }

            // mint the tokens
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            DelegatorInfo memory info = DelegatorInfo(currentFullNounder, tokenIds);
            agnosticDelegatorsTemp.push(info);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
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

        // assert `fullDelegatorsTemp` array was populated correctly
        assertEq(agnosticDelegatorsTemp.length, uint256(numSupplementaryDelegations) + uint256(numFullDelegations));

        // construct `indiciesToDisqualify` array
        bool delegateOrTransfer;
        IPropLot.Delegation[] memory optimisticDelegations = propLot.getOptimisticDelegations();

        uint256[] memory unTruncatedIndiciesToDisqualify = new uint256[](optimisticDelegations.length);
        // populate array with indices
        for (uint256 z; z < unTruncatedIndiciesToDisqualify.length; ++z) unTruncatedIndiciesToDisqualify[z] = z;
        
        // perform Fisher-Yates shuffle on `optimisticDelegations` indices to create a random permutation
        for (uint256 k; k < optimisticDelegations.length; k++) {
            uint256 remaining = optimisticDelegations.length - k;
            uint256 l = uint256(keccak256(abi.encode(k))) % remaining + k;
            // swap unTruncatedIndiciesToDisqualify[k] and unTruncatedIndiciesToDisqualify[l]
            (unTruncatedIndiciesToDisqualify[k], unTruncatedIndiciesToDisqualify[l]) = (unTruncatedIndiciesToDisqualify[l], unTruncatedIndiciesToDisqualify[k]);
        }

        uint256[] memory indiciesToDisqualify = new uint256[](numDisqualifications);
        // then truncate resulting shuffled array to obtain randomized array of indices to delete
        for (uint256 m; m < numDisqualifications; ++m) {
            // populate expected return array
            indiciesToDisqualify[m] = unTruncatedIndiciesToDisqualify[m];
            
            // perform disqualifications
            address currentDelegator = optimisticDelegations[unTruncatedIndiciesToDisqualify[m]].delegator;
            vm.startPrank(currentDelegator);
            if (delegateOrTransfer) {
                // disqualify via delegation
                nounsTokenHarness.delegate(address(0x69));
            } else { // disqualify via transfer
                uint256 index;
                // find delegator index in `agnosticDelegatorsTemp`
                for (uint256 n; n < agnosticDelegatorsTemp.length; ++n) {
                    if (agnosticDelegatorsTemp[n].nounder == currentDelegator) index = n;
                }

                DelegatorInfo storage info = agnosticDelegatorsTemp[index];
                assertEq(info.nounder, currentDelegator); // sanity check

                uint256 numTransfers = uint256(keccak256(abi.encode(m))) % info.ownedTokenIds.length + 1; 
                for (uint256 o; o < numTransfers; ++o) {
                    uint256 tokenId = info.ownedTokenIds[o];
                    NounsTokenHarness(address(nounsTokenHarness)).transferFrom(currentDelegator, address(0x69), tokenId);
                }
            }
            vm.stopPrank();

            delegateOrTransfer = !delegateOrTransfer;
        }

        uint256[] memory returnedDisqualifiedIndices = propLot.disqualifiedDelegationIndices();
        assertEq(returnedDisqualifiedIndices.length, indiciesToDisqualify.length);

        // assert all members of `indiciesToDisqualify` are present in `returnedDisqualifiedIndices`
        for (uint256 o; o < indiciesToDisqualify.length; ++o) {
            bool matchFound;
            for (uint256 p; p < returnedDisqualifiedIndices.length; ++p) {
                if (returnedDisqualifiedIndices[p] == indiciesToDisqualify[o]) matchFound = true;
            }
            
            assertTrue(matchFound);
        }
    }

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

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = propLot.getCurrentMinRequiredVotes();
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
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

    function test_deleteDelegationsZeroMembers(uint8 numSupplementaryDelegations, uint8 numFullDelegations) public {
        vm.assume(numSupplementaryDelegations > 0 || numFullDelegations > 0);

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

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = propLot.getCurrentMinRequiredVotes();
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 minRequiredVotes = propLot.getCurrentMinRequiredVotes();
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

        // used for assertion
        IPropLot.Delegation[] memory arrayBeforeDeletion = propLot.getOptimisticDelegations();

        // create empty array
        uint256[] memory indicesToDelete = new uint256[](0);

        // delete zero delegations
        propLot.deleteDelegations(indicesToDelete);

        // asserts
        IPropLot.Delegation[] memory arrayAfterDeletion = propLot.getOptimisticDelegations();
        assertEq(arrayBeforeDeletion.length, arrayAfterDeletion.length);
    }

    function test_computeNounsDelegationDigest(uint8 numSigners, uint8 fuzzDelegateId, uint8 expiryOffset) public {
        vm.assume(fuzzDelegateId != 0); // filter invalid delegate IDs

        for (uint256 i; i < numSigners; ++i) {
            address signer = _createNounderEOA(i);

            // signer does not hold Nouns tokens but in this case it does not matter
            address delegate = propLot.getDelegateAddress(fuzzDelegateId);
            bytes32 nounsDomainSeparator = keccak256(abi.encode(
                nounsTokenHarness.DOMAIN_TYPEHASH(), 
                keccak256(bytes(nounsTokenHarness.name())), 
                block.chainid, 
                address(nounsTokenHarness)
            ));

            uint256 nonce = nounsTokenHarness.nonces(signer);
            uint256 expiry = block.timestamp + expiryOffset;
            bytes32 structHash = keccak256(
                abi.encode(nounsTokenHarness.DELEGATION_TYPEHASH(), delegate, nonce, expiry)
            );
            
            // construct digest manually and check it against PropLot Core's returned value
            bytes32 digest = keccak256(abi.encodePacked('\x19\x01', nounsDomainSeparator, structHash));
            bytes32 returnedDigest = propLot.computeNounsDelegationDigest(signer, fuzzDelegateId, expiry);
            assertEq(digest, returnedDigest);
        }
    }

    function test_findDelegateId(uint8 numDelegations, uint8 fuzzedMinRequiredVotes) public {
        vm.assume(numDelegations > 1); // at least one supplementary and one full
        vm.assume(fuzzedMinRequiredVotes >= 2); // current minimum is 2

        // scope test to find delegate only
        bool isSupplementary;
        for (uint256 i; i < numDelegations; ++i) {
            uint256 delegateId = propLot.getDelegateIdByType(fuzzedMinRequiredVotes, isSupplementary);
            address delegate = propLot.getDelegateAddress(delegateId);
            uint256 amt = isSupplementary ? fuzzedMinRequiredVotes / 2 : fuzzedMinRequiredVotes;
            address currentNounder = _createNounderEOA(i);
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentNounder, amt);

            vm.startPrank(currentNounder);
            nounsTokenHarness.delegate(delegate);
            propLot.registerDelegation(currentNounder, delegateId, amt);

            isSupplementary = !isSupplementary;
        }

        uint256 returnedSupplementaryId =  propLot.findDelegateId(fuzzedMinRequiredVotes, true);
        address returnedSupplementaryDelegate = propLot.getDelegateAddress(returnedSupplementaryId);
        assertTrue(nounsTokenHarness.getCurrentVotes(returnedSupplementaryDelegate) < fuzzedMinRequiredVotes);

        // expected full ID should be an uncreated one
        uint256 expectedFullId = propLot.getNextDelegateId();
        uint256 returnedFullId = propLot.findDelegateId(fuzzedMinRequiredVotes, false);
        assertEq(expectedFullId, returnedFullId);
        address returnedFullDelegate = propLot.getDelegateAddress(returnedFullId);
        assertEq(nounsTokenHarness.getCurrentVotes(returnedFullDelegate), 0);
    }
    //function test_findProposerDelegate
    //function test_checkForActiveProposal
}