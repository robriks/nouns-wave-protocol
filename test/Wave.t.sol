// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Wave} from "src/Wave.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";
import {NounsEnvSetup} from "test/helpers/NounsEnvSetup.sol";
import {TestUtils} from "test/helpers/TestUtils.sol";

/// @notice Fuzz iteration params can be increased to larger types to match implementation
/// They are temporarily set to smaller types for speed only
/// @dev This IdeaTokenHub test suite inherits from the Nouns governance setup contract to mimic the onchain environment
contract WaveTest is NounsEnvSetup, TestUtils {
    WaveHarness waveCoreImpl;
    WaveHarness waveCore;
    IdeaTokenHub ideaTokenHubImpl;
    IdeaTokenHub ideaTokenHub;

    struct DelegatorInfo {
        address nounder;
        uint256[] ownedTokenIds;
    }

    uint256 waveLength;
    uint256 minSponsorshipAmount;
    string uri;
    ProposalTxs txs;
    string description;
    // for fuzzing purposes, should remain empty until `numEligibleProposers` is known
    IWave.Proposal[] proposals;
    DelegatorInfo[] supplementaryDelegatorsTemp;
    DelegatorInfo[] fullDelegatorsTemp;
    DelegatorInfo[] agnosticDelegatorsTemp;

    uint256 nounderSupplementPK;
    uint256 nounderSupplement2PK;
    uint256 nounderSoloPK;
    address nounderSupplement;
    address nounderSupplement2;
    address nounderSolo;

    // copied from Wave to facilitate event testing
    event DelegateCreated(address delegate, uint256 id);
    event DelegationRegistered(IWave.Delegation optimisticDelegation);
    event DelegationDeleted(IWave.Delegation disqualifiedDelegation);

    function setUp() public {
        // establish clone of onchain Nouns governance environment
        super.setUpNounsGovernance();

        // setup Wave contracts
        waveLength = 100800;
        minSponsorshipAmount = 0.00077 ether;
        uri = "someURI";
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

        super.mintMirrorBalances();

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
        assertEq(waveCore.getOptimisticDelegations().length, 0);

        uint256 totalSupply = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).ownerOf(totalSupply - 4), nounderSupplement);
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).ownerOf(totalSupply - 3), nounderSupplement2);
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).ownerOf(totalSupply - 2), nounderSolo);

        address firstDelegate = waveCore.getDelegateAddress(1);
        assertTrue(firstDelegate.code.length > 0);
        assertTrue(firstDelegate == waveCore.simulateCreate2(bytes32(uint256(1)), waveCore.__creationCodeHash()));

        uint256 nextDelegateId = waveCore.getNextDelegateId();
        assertEq(nextDelegateId, 2);

        uint256 minRequiredVotesExpected = nounsGovernorProxy.proposalThreshold() + 1;
        uint256 minRequiredVotesReturned = waveCore.getCurrentMinRequiredVotes();
        assertEq(minRequiredVotesExpected, minRequiredVotesReturned);
        uint256 incompleteDelegateId = waveCore.getDelegateIdByType(minRequiredVotesReturned, true);
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
            address resultDelegate = waveCore.getDelegateAddress(fuzzDelegateId);

            address actualDelegate = waveCore.createDelegate();
            assertEq(resultDelegate, actualDelegate);
        }
    }

    function test_revertGetDelegateAddressInvalidDelegateId() public {
        bytes memory err = abi.encodeWithSelector(IWave.InvalidDelegateId.selector, 0);
        vm.expectRevert(err);
        waveCore.getDelegateAddress(0);
    }

    function test_createDelegate(uint8 fuzzIterations) public {
        uint256 startDelegateId = waveCore.getNextDelegateId();
        assertEq(startDelegateId, 2);

        for (uint16 i; i < fuzzIterations; ++i) {
            uint256 fuzzDelegateId = startDelegateId + i;
            address resultDelegate = waveCore.getDelegateAddress(fuzzDelegateId);
            assertTrue(resultDelegate.code.length == 0);

            vm.expectEmit(true, false, false, false);
            emit DelegateCreated(resultDelegate, fuzzDelegateId);
            address createdDelegate = waveCore.createDelegate();
            assertTrue(resultDelegate.code.length != 0);
            assertEq(resultDelegate, createdDelegate);

            // assert next delegate ID was incremented
            uint256 nextDelegateId = waveCore.getNextDelegateId();
            assertEq(fuzzDelegateId + 1, nextDelegateId);
        }
    }

    function test_simulateCreate2(uint8 fuzzIterations) public {
        address firstDelegate = waveCore.getDelegateAddress(1);
        assertTrue(firstDelegate.code.length != 0);
        assertTrue(firstDelegate == waveCore.simulateCreate2(bytes32(uint256(1)), waveCore.__creationCodeHash()));

        uint256 startDelegateId = waveCore.getNextDelegateId();

        for (uint256 i; i < fuzzIterations; ++i) {
            uint256 fuzzDelegateId = startDelegateId + i;
            address expectedDelegate = waveCore.simulateCreate2(bytes32(fuzzDelegateId), waveCore.__creationCodeHash());
            address createdDelegate = waveCore.createDelegate();
            assertEq(expectedDelegate, createdDelegate);
            assertEq(expectedDelegate, waveCore.getDelegateAddress(fuzzDelegateId));
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

        uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
        uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, true);
        assertEq(delegateId, 1);
        assertEq(minRequiredVotes, 2);

        address delegate = waveCore.getDelegateAddress(delegateId);
        (address suitableDelegate,) = waveCore.getSuitableDelegateFor(nounderSupplement);
        assertEq(suitableDelegate, delegate);

        // perform external delegation to relevant delegate
        vm.prank(nounderSupplement);
        nounsTokenHarness.delegate(delegate);

        address delegated = nounsTokenHarness.delegates(nounderSupplement);
        assertEq(delegated, delegate);

        uint256 nextCheckpoints = nounsTokenHarness.numCheckpoints(nounderSupplement);
        assertEq(nextCheckpoints, startCheckpoints + 1);
        uint256 nextDelegateId = waveCore.getNextDelegateId();

        IWave.Delegation memory delegation =
            IWave.Delegation(nounderSupplement, uint32(block.number), uint16(votingPower), uint16(delegateId));
        vm.expectEmit(true, false, false, false);
        emit DelegationRegistered(delegation);
        vm.prank(nounderSupplement);
        waveCore.registerDelegation(nounderSupplement, delegateId);

        // assert no new delegate was created
        assertEq(nextDelegateId, waveCore.getNextDelegateId());

        IWave.Delegation[] memory optimisticDelegations = waveCore.getOptimisticDelegations();
        assertEq(optimisticDelegations.length, 1);
        assertEq(optimisticDelegations[0].delegator, nounderSupplement);
        assertEq(optimisticDelegations[0].blockDelegated, uint32(block.number));
        assertEq(optimisticDelegations[0].votingPower, uint16(votingPower));
        assertEq(optimisticDelegations[0].delegateId, uint16(delegateId));

        uint256 existingSupplementId = waveCore.getDelegateIdByType(minRequiredVotes, true);
        assertEq(existingSupplementId, delegateId);

        uint256 expectNewDelegateId = waveCore.getDelegateIdByType(minRequiredVotes, false);
        assertEq(expectNewDelegateId, nextDelegateId);

        // the delegation should not register as an eligible proposer
        (, uint256[] memory allEligibleProposerIds) = waveCore.getAllEligibleProposerDelegates();
        assertEq(allEligibleProposerIds.length, 0);
        // the partial delegation should be found
        (, address[] memory allPartialDelegates) = waveCore.getAllPartialDelegates();
        assertEq(allPartialDelegates.length, 1);
        assertEq(allPartialDelegates[0], delegate);

        // proposal cannot pushed using the first delegate after 1 block as it requires another vote
        vm.roll(block.number + 1);
        vm.prank(address(waveCore));
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

        uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, true);
        assertEq(delegateId, 1);
        address delegate = waveCore.getDelegateAddress(delegateId);
        (address suitableDelegate,) = waveCore.getSuitableDelegateFor(nounderSolo);
        assertEq(suitableDelegate, delegate);

        // perform external delegation to relevant delegate
        vm.prank(nounderSolo);
        nounsTokenHarness.delegate(delegate);

        address delegated = nounsTokenHarness.delegates(nounderSolo);
        assertEq(delegated, delegate);

        uint256 nextCheckpoints = nounsTokenHarness.numCheckpoints(nounderSolo);
        assertEq(nextCheckpoints, startCheckpoints + 1);
        uint256 nextDelegateId = waveCore.getNextDelegateId();
        assertEq(nextDelegateId, 2);

        IWave.Delegation memory delegation =
            IWave.Delegation(nounderSolo, uint32(block.number), uint16(votingPower), uint16(delegateId));
        vm.expectEmit(true, false, false, false);
        emit DelegationRegistered(delegation);
        vm.prank(nounderSolo);
        waveCore.registerDelegation(nounderSolo, delegateId);

        // assert no new delegate was created
        assertEq(nextDelegateId, waveCore.getNextDelegateId());

        IWave.Delegation[] memory optimisticDelegations = waveCore.getOptimisticDelegations();
        assertEq(optimisticDelegations.length, 1);
        assertEq(optimisticDelegations[0].delegator, nounderSolo);
        assertEq(optimisticDelegations[0].blockDelegated, uint32(block.number));
        assertEq(optimisticDelegations[0].votingPower, uint16(votingPower));
        assertEq(optimisticDelegations[0].delegateId, uint16(delegateId));

        // delegateId 1 is saturated so getDelegateIdByType should always return nextDelegateId
        uint256 returnedSoloId = waveCore.getDelegateIdByType(minRequiredVotes, true);
        assertEq(returnedSoloId, nextDelegateId);
        uint256 returnedSupplementDelegateId = waveCore.getDelegateIdByType(minRequiredVotes, false);
        assertEq(returnedSupplementDelegateId, nextDelegateId);

        // the delegation should register as an eligible proposer
        (, uint256[] memory allEligibleProposerIds) = waveCore.getAllEligibleProposerDelegates();
        assertEq(allEligibleProposerIds.length, 1);
        assertEq(waveCore.getDelegateAddress(allEligibleProposerIds[0]), delegate);
        // no partial delegates should be found
        (, address[] memory allPartialDelegates) = waveCore.getAllPartialDelegates();
        assertEq(allPartialDelegates.length, 0);

        // proposal can now be pushed using the first delegate after 1 block (simple POC)
        vm.roll(block.number + 1);
        vm.prank(address(waveCore));
        Delegate(delegate).pushProposal(INounsDAOLogicV3(address(nounsGovernorProxy)), txs, description);
    }

    function test_delegateBySig(uint8 numSigners, uint8 fuzzDelegateId, uint8 expiryOffset) public {
        vm.assume(fuzzDelegateId != 0); // filter invalid delegate IDs

        for (uint256 i; i < numSigners; ++i) {
            address signer = _createNounderEOA(i);
            uint256 privKey = i + 1; // under the hood, `_createNounderEOA` uses incremented value as private key

            // signer does not hold Nouns tokens but in this case it does not matter
            address delegate = waveCore.getDelegateAddress(fuzzDelegateId);
            bytes32 nounsDomainSeparator = keccak256(
                abi.encode(
                    nounsTokenHarness.DOMAIN_TYPEHASH(),
                    keccak256(bytes(nounsTokenHarness.name())),
                    block.chainid,
                    address(nounsTokenHarness)
                )
            );

            uint256 nonce = nounsTokenHarness.nonces(signer);
            uint256 expiry = block.timestamp + expiryOffset;
            bytes32 structHash = keccak256(abi.encode(nounsTokenHarness.DELEGATION_TYPEHASH(), delegate, nonce, expiry));

            // construct digest manually and check it against Wave Core's returned value
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", nounsDomainSeparator, structHash));
            bytes32 returnedDigest = waveCore.computeNounsDelegationDigest(signer, fuzzDelegateId, expiry);
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
            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
            uint256 notMinRequiredVotes = minRequiredVotes / 2;
            for (uint256 j; j < notMinRequiredVotes; ++j) {
                NounsTokenHarness(address(nounsTokenHarness)).mintTo(currentSupplementaryNounder);
            }
            uint256 returnedSupplementaryBalance =
                NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
            assertEq(returnedSupplementaryBalance, notMinRequiredVotes);

            uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, true);
            address delegate = waveCore.getDelegateAddress(delegateId);

            vm.startPrank(currentSupplementaryNounder);
            nounsTokenHarness.delegate(delegate);
            waveCore.registerDelegation(currentSupplementaryNounder, delegateId);
            vm.stopPrank();
        }

        for (uint256 k; k < numFullDelegations; ++k) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `k` to get new addresses
            address currentFullNounder = _createNounderEOA(k + numSupplementaryDelegations);
            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();

            for (uint256 l; l < minRequiredVotes; ++l) {
                NounsTokenHarness(address(nounsTokenHarness)).mintTo(currentFullNounder);
            }
            uint256 returnedFullBalance = NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, minRequiredVotes);

            uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, false);
            address delegate = waveCore.getDelegateAddress(delegateId);

            vm.startPrank(currentFullNounder);
            nounsTokenHarness.delegate(delegate);
            waveCore.registerDelegation(currentFullNounder, delegateId);
            vm.stopPrank();
        }

        // populate proposals storage array only once `numEligibleProposers` is known
        (, uint256 numEligibleProposers) = waveCore.numEligibleProposerDelegates();
        for (uint256 m; m < numEligibleProposers; ++m) {
            proposals.push(IWave.Proposal(txs, description));
        }

        // push proposal to Nouns ecosystem
        vm.roll(block.number + 1);
        vm.prank(address(ideaTokenHub));
        (IWave.Delegation[] memory validDels, uint256[] memory proposalIds) = waveCore.pushProposals(proposals);

        // disqualifications out of scope for this test so there are none
        assertEq(validDels.length, uint256(numFullDelegations) + uint256(numSupplementaryDelegations));
        assertEq(proposalIds.length, numEligibleProposers);
    }

    function test_pushProposalsRemoveRogueDelegators(uint8 numSupplementaryDelegations, uint8 numFullDelegations)
        public
    {
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
            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // assert `agnosticDelegatorsTemp` array was populated correctly
        assertEq(agnosticDelegatorsTemp.length, numSupplementaryDelegations);

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = waveCore.getCurrentMinRequiredVotes();

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

            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // assert `fullDelegatorsTemp` array was populated correctly
        assertEq(agnosticDelegatorsTemp.length, uint256(numSupplementaryDelegations) + uint256(numFullDelegations));

        // construct `indiciesToDisqualify` array
        bool delegateOrTransfer;
        IWave.Delegation[] memory optimisticDelegations = waveCore.getOptimisticDelegations();

        uint256[] memory unTruncatedIndiciesToDisqualify = new uint256[](optimisticDelegations.length);
        // populate array with indices
        for (uint256 z; z < unTruncatedIndiciesToDisqualify.length; ++z) {
            unTruncatedIndiciesToDisqualify[z] = z;
        }

        // perform Fisher-Yates shuffle on `optimisticDelegations` indices to create a random permutation
        for (uint256 k; k < optimisticDelegations.length; k++) {
            uint256 remaining = optimisticDelegations.length - k;
            uint256 l = uint256(keccak256(abi.encode(k))) % remaining + k;
            // swap unTruncatedIndiciesToDisqualify[k] and unTruncatedIndiciesToDisqualify[l]
            (unTruncatedIndiciesToDisqualify[k], unTruncatedIndiciesToDisqualify[l]) =
                (unTruncatedIndiciesToDisqualify[l], unTruncatedIndiciesToDisqualify[k]);
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
            } else {
                // disqualify via transfer
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

        uint256[] memory returnedDisqualifiedIndices = waveCore.disqualifiedDelegationIndices();
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
        (, uint256 numEligibleProposers) = waveCore.numEligibleProposerDelegates();
        for (uint256 m; m < numEligibleProposers; ++m) {
            proposals.push(IWave.Proposal(txs, description));
        }

        // push proposal to Nouns ecosystem
        vm.roll(block.number + 1);
        vm.prank(address(ideaTokenHub));
        (IWave.Delegation[] memory validDels, uint256[] memory proposalIds) = waveCore.pushProposals(proposals);

        // disqualifications out of scope for this test so there are none
        uint256 numExpectedProposals =
            uint256(numFullDelegations) + uint256(numSupplementaryDelegations) - numDisqualifications;
        assertEq(validDels.length, numExpectedProposals);
        assertEq(proposalIds.length, numEligibleProposers);
    }

    function test_revertPushProposalsNotIdeaTokenHub() public {
        bytes memory err = abi.encodeWithSelector(IWave.Unauthorized.selector);
        vm.expectRevert(err);
        waveCore.pushProposals(proposals);
    }

    function test_revertPushProposalsInsufficientDelegations() public {
        delete proposals;

        bytes memory err = abi.encodeWithSelector(IWave.InsufficientDelegations.selector);
        vm.prank(address(ideaTokenHub));
        vm.expectRevert(err);
        waveCore.pushProposals(proposals);
    }

    function test_revertPushProposalNotWave() public {
        Delegate firstDelegate = Delegate(waveCore.getDelegateAddress(1));

        bytes memory err = abi.encodeWithSelector(Delegate.NotWaveCore.selector, address(this));
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
                minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
                uint256 amt = minRequiredVotes / 2;

                // mint `amt < minRequiredVotes` to new nounder EOA and delegate
                NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentSupplementaryNounder, amt);
                uint256 returnedSupplementaryBalance =
                    NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentSupplementaryNounder);
                assertEq(returnedSupplementaryBalance, amt);

                uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, true);
                address delegate = waveCore.getDelegateAddress(delegateId);

                vm.startPrank(currentSupplementaryNounder);
                nounsTokenHarness.delegate(delegate);
                waveCore.registerDelegation(currentSupplementaryNounder, delegateId);
                vm.stopPrank();

                ++supplementaryCounter;
            } else {
                // perform full delegation
                address currentFullNounder = _createNounderEOA(delCounter);
                uint256 amt = waveCore.getCurrentMinRequiredVotes();

                // mint `amt == minRequiredVotes` to new nounder EOA and delegate
                NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);
                uint256 returnedFullBalance = NounsTokenLike(address(nounsTokenHarness)).balanceOf(currentFullNounder);
                assertEq(returnedFullBalance, amt);

                minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
                uint256 delegateId = waveCore.getDelegateIdByType(minRequiredVotes, false);
                address delegate = waveCore.getDelegateAddress(delegateId);

                vm.startPrank(currentFullNounder);
                nounsTokenHarness.delegate(delegate);
                waveCore.registerDelegation(currentFullNounder, delegateId);
                vm.stopPrank();
            }

            ++delCounter;
        }

        // assert that delegate returned by getDelegateIdByType has votingPower < or > minRequiredVotes
        minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
        uint256 supplementId = waveCore.getDelegateIdByType(minRequiredVotes, true);
        uint256 fullId = waveCore.getDelegateIdByType(minRequiredVotes, false);

        IWave.Delegation[] memory optimisticDelegations = waveCore.getOptimisticDelegations();
        bool supplementMatchFound;
        bool fullMatchFound;
        uint256 nextDelegateId = waveCore.getNextDelegateId();
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

        address supplement = waveCore.getDelegateAddress(supplementId);
        uint256 supplementVotes = nounsTokenHarness.getCurrentVotes(supplement);
        // if the `supplementId` returned by `getDelegateIdByType()` is the next delegate id, that Delegate address
        // will have 0 votes, thus the `votingPower` assert is only necessary if a partially saturated Delegate ID was returned
        if (supplementId != nextDelegateId) {
            assertTrue(supplementVotes < minRequiredVotes);
        } else {
            assertEq(supplementVotes, 0);
        }

        address full = waveCore.getDelegateAddress(fullId);
        uint256 fullVotes = nounsTokenHarness.getCurrentVotes(full);
        // if the `fullId` returned by `getDelegateIdByType()` is the next delegate id, that Delegate address
        // will have 0 votes, thus the `votingPower` assert is only necessary if a totally unsaturated Delegate ID was returned
        if (fullId != nextDelegateId) {
            assertTrue(fullVotes >= minRequiredVotes);
        } else {
            assertEq(fullVotes, 0);
        }
    }

    function test_isDisqualifiedRedelegate(
        uint8 numSupplementaryDelegations,
        uint8 numFullDelegations,
        uint8 numSupplementaryDisqualifications,
        uint8 numFullDisqualifications
    ) public {
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
            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = waveCore.getCurrentMinRequiredVotes();

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

            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        IWave.Delegation[] memory optimisticDelegations = waveCore.getOptimisticDelegations();
        bool redelegateToWave; // conditionally have disqualifying users redelegate to protocol
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
                    originalDelegate = waveCore.getDelegateAddress(originalId);
                    votingPower = optimisticDelegations[l].votingPower;
                }
            }
            assertTrue(originalDelegate != address(0x0)); // sanity check a match was found

            // flip between compliant and noncompliant behavior
            if (redelegateToWave) {
                vm.prank(currentDisqualified);
                nounsTokenHarness.delegate(originalDelegate);

                // roll forward a block to update votes
                vm.roll(block.number + 1);
            }

            bool disqualify = waveCore.isDisqualified(currentDisqualified, originalDelegate, votingPower);
            // redelegations are allowed only if Nounder returns registered amount of voting power to registered delegate
            if (redelegateToWave) {
                assertFalse(disqualify);
            } else {
                assertTrue(disqualify);
            }

            redelegateToWave = !redelegateToWave;
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
                    originalDelegate = waveCore.getDelegateAddress(originalId);
                    votingPower = optimisticDelegations[n].votingPower;
                }
            }
            assertTrue(originalDelegate != address(0x0));

            // flip between compliant and noncompliant behavior
            if (redelegateToWave) {
                vm.prank(currentDisqualified);
                nounsTokenHarness.delegate(originalDelegate);
                // roll forward a block to update votes
                vm.roll(block.number + 1);
            }

            bool disqualify = waveCore.isDisqualified(currentDisqualified, originalDelegate, votingPower);
            // redelegations are allowed only if Nounder returns registered amount of voting power to registered delegate
            if (redelegateToWave) {
                assertFalse(disqualify);
            } else {
                assertTrue(disqualify);
            }

            redelegateToWave = !redelegateToWave;
        }
    }

    function test_isDisqualifiedTransfer(
        uint8 numSupplementaryDelegations,
        uint8 numFullDelegations,
        uint8 numSupplementaryDisqualifications,
        uint8 numFullDisqualifications
    ) public {
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
            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // assert `supplementaryDelegatorsTemp` array was populated correctly
        assertEq(supplementaryDelegatorsTemp.length, numSupplementaryDelegations);

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = waveCore.getCurrentMinRequiredVotes();

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

            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // assert `fullDelegatorsTemp` array was populated correctly
        assertEq(fullDelegatorsTemp.length, numFullDelegations);

        IWave.Delegation[] memory optimisticDelegations = waveCore.getOptimisticDelegations();
        bool transferBackToWave; // conditionally have disqualifying users transfer back to protocol
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
                    originalDelegate = waveCore.getDelegateAddress(originalId);
                    votingPower = optimisticDelegations[l].votingPower;
                }
            }

            assertTrue(originalDelegate != address(0x0)); // sanity check a match was found

            // flip between compliant and noncompliant behavior
            if (transferBackToWave) {
                for (uint256 x; x < pseudoRandomTransferAmt; ++x) {
                    uint256 tokenId = supplementaryDelegatorsTemp[k].ownedTokenIds[x];
                    NounsTokenHarness(address(nounsTokenHarness)).transferFrom(
                        address(this), currentDisqualified, tokenId
                    );

                    // roll forward a block to update votes (checkpoints update only once when transfers are within same block)
                    vm.roll(block.number + 1);
                }
            }

            bool disqualify = waveCore.isDisqualified(currentDisqualified, originalDelegate, votingPower);
            // redelegations are allowed only if Nounder returns registered amount of voting power to registered delegate
            if (transferBackToWave) {
                assertFalse(disqualify);
            } else {
                assertTrue(disqualify);
            }

            transferBackToWave = !transferBackToWave;
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
                    originalDelegate = waveCore.getDelegateAddress(originalId);
                    votingPower = optimisticDelegations[n].votingPower;
                }
            }
            assertTrue(originalDelegate != address(0x0));

            // flip between compliant and noncompliant behavior
            if (transferBackToWave) {
                for (uint256 x; x < pseudoRandomTransferAmt; ++x) {
                    uint256 tokenId = fullDelegatorsTemp[m].ownedTokenIds[x];
                    NounsTokenHarness(address(nounsTokenHarness)).transferFrom(
                        address(this), currentDisqualified, tokenId
                    );

                    // roll forward a block to update votes (checkpoints update only once when transfers are within same block)
                    vm.roll(block.number + 1);
                }
            }

            bool disqualify = waveCore.isDisqualified(currentDisqualified, originalDelegate, votingPower);
            // redelegations are allowed only if Nounder returns registered amount of voting power to registered delegate
            if (transferBackToWave) {
                assertFalse(disqualify);
            } else {
                assertTrue(disqualify);
            }

            transferBackToWave = !transferBackToWave;
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
            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // assert `agnosticDelegatorsTemp` array was populated correctly
        assertEq(agnosticDelegatorsTemp.length, numSupplementaryDelegations);

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = waveCore.getCurrentMinRequiredVotes();

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

            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // assert `fullDelegatorsTemp` array was populated correctly
        assertEq(agnosticDelegatorsTemp.length, uint256(numSupplementaryDelegations) + uint256(numFullDelegations));

        // construct `indiciesToDisqualify` array
        bool delegateOrTransfer;
        IWave.Delegation[] memory optimisticDelegations = waveCore.getOptimisticDelegations();

        uint256[] memory unTruncatedIndiciesToDisqualify = new uint256[](optimisticDelegations.length);
        // populate array with indices
        for (uint256 z; z < unTruncatedIndiciesToDisqualify.length; ++z) {
            unTruncatedIndiciesToDisqualify[z] = z;
        }

        // perform Fisher-Yates shuffle on `optimisticDelegations` indices to create a random permutation
        for (uint256 k; k < optimisticDelegations.length; k++) {
            uint256 remaining = optimisticDelegations.length - k;
            uint256 l = uint256(keccak256(abi.encode(k))) % remaining + k;
            // swap unTruncatedIndiciesToDisqualify[k] and unTruncatedIndiciesToDisqualify[l]
            (unTruncatedIndiciesToDisqualify[k], unTruncatedIndiciesToDisqualify[l]) =
                (unTruncatedIndiciesToDisqualify[l], unTruncatedIndiciesToDisqualify[k]);
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
            } else {
                // disqualify via transfer
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

        uint256[] memory returnedDisqualifiedIndices = waveCore.disqualifiedDelegationIndices();
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

    function test_deleteDelegations(uint8 numSupplementaryDelegations, uint8 numFullDelegations, uint8 numDeletions)
        public
    {
        vm.assume(numSupplementaryDelegations > 0 || numFullDelegations > 0);
        uint256 totalDelegations = uint256(numSupplementaryDelegations) + uint256(numFullDelegations);
        vm.assume(numDeletions > 0 && numDeletions < totalDelegations);

        bool eoa; // used to alternate simulating EOA users and smart contract wallet users
        // make fuzzed supplementary delegations
        for (uint256 i; i < numSupplementaryDelegations; ++i) {
            address currentSupplementaryNounder = eoa ? _createNounderEOA(i) : _createNounderSmartAccount(i);
            // mint `minRequiredVotes / 2` to new nounder and delegate
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

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = waveCore.getCurrentMinRequiredVotes();
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // used for assertions
        IWave.Delegation[] memory arrayBeforeDeletion = waveCore.getOptimisticDelegations();

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
        IWave.Delegation[] memory delegationsToDelete = new IWave.Delegation[](numDeletions);
        for (uint256 z; z < numDeletions; ++z) {
            delegationsToDelete[z] = arrayBeforeDeletion[indicesToDelete[z]];
        }

        // assert all events emitted properly
        for (uint256 n; n < indicesToDelete.length; ++n) {
            vm.expectEmit(true, true, true, false);
            emit IWave.DelegationDeleted(arrayBeforeDeletion[indicesToDelete[n]]);
        }

        // delete fuzzed number of delegations
        waveCore.deleteDelegations(indicesToDelete);

        // asserts
        IWave.Delegation[] memory arrayAfterDeletion = waveCore.getOptimisticDelegations();
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

        // perform fuzzed full delegations
        for (uint256 j; j < numFullDelegations; ++j) {
            // mint `minRequiredVotes`to new nounder and delegate, adding `numSupplementaryDelegates` to `j` to get new addresses
            address currentFullNounder = _createNounderEOA(j + numSupplementaryDelegations);
            uint256 amt = waveCore.getCurrentMinRequiredVotes();
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentFullNounder, amt);

            uint256 returnedFullBalance = NounsTokenHarness(address(nounsTokenHarness)).balanceOf(currentFullNounder);
            assertEq(returnedFullBalance, amt);

            uint256 minRequiredVotes = waveCore.getCurrentMinRequiredVotes();
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

        // used for assertion
        IWave.Delegation[] memory arrayBeforeDeletion = waveCore.getOptimisticDelegations();

        // create empty array
        uint256[] memory indicesToDelete = new uint256[](0);

        // delete zero delegations
        waveCore.deleteDelegations(indicesToDelete);

        // asserts
        IWave.Delegation[] memory arrayAfterDeletion = waveCore.getOptimisticDelegations();
        assertEq(arrayBeforeDeletion.length, arrayAfterDeletion.length);
    }

    function test_computeNounsDelegationDigest(uint8 numSigners, uint8 fuzzDelegateId, uint8 expiryOffset) public {
        vm.assume(fuzzDelegateId != 0); // filter invalid delegate IDs

        for (uint256 i; i < numSigners; ++i) {
            address signer = _createNounderEOA(i);

            // signer does not hold Nouns tokens but in this case it does not matter
            address delegate = waveCore.getDelegateAddress(fuzzDelegateId);
            bytes32 nounsDomainSeparator = keccak256(
                abi.encode(
                    nounsTokenHarness.DOMAIN_TYPEHASH(),
                    keccak256(bytes(nounsTokenHarness.name())),
                    block.chainid,
                    address(nounsTokenHarness)
                )
            );

            uint256 nonce = nounsTokenHarness.nonces(signer);
            uint256 expiry = block.timestamp + expiryOffset;
            bytes32 structHash = keccak256(abi.encode(nounsTokenHarness.DELEGATION_TYPEHASH(), delegate, nonce, expiry));

            // construct digest manually and check it against Wave Core's returned value
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", nounsDomainSeparator, structHash));
            bytes32 returnedDigest = waveCore.computeNounsDelegationDigest(signer, fuzzDelegateId, expiry);
            assertEq(digest, returnedDigest);
        }
    }

    function test_findDelegateId(uint8 numDelegations, uint8 fuzzedMinRequiredVotes) public {
        vm.assume(numDelegations > 1); // at least one supplementary and one full
        vm.assume(fuzzedMinRequiredVotes >= 2); // current minimum is 2
        vm.assume(uint(numDelegations) + uint(fuzzedMinRequiredVotes) < 200); // constrain to prevent running out of gas during mints

        // scope test to find delegate only
        bool isSupplementary;
        for (uint256 i; i < numDelegations; ++i) {
            uint256 delegateId = waveCore.getDelegateIdByType(fuzzedMinRequiredVotes, isSupplementary);
            address delegate = waveCore.getDelegateAddress(delegateId);
            uint256 amt = isSupplementary ? fuzzedMinRequiredVotes / 2 : fuzzedMinRequiredVotes;
            address currentNounder = _createNounderEOA(i);
            NounsTokenHarness(address(nounsTokenHarness)).mintMany(currentNounder, amt);

            vm.startPrank(currentNounder);
            nounsTokenHarness.delegate(delegate);
            waveCore.registerDelegation(currentNounder, delegateId);

            isSupplementary = !isSupplementary;
        }

        uint256 returnedSupplementaryId = waveCore.findDelegateId(fuzzedMinRequiredVotes, true);
        address returnedSupplementaryDelegate = waveCore.getDelegateAddress(returnedSupplementaryId);
        assertTrue(nounsTokenHarness.getCurrentVotes(returnedSupplementaryDelegate) < fuzzedMinRequiredVotes);

        // expected full ID should be an uncreated one
        uint256 expectedFullId = waveCore.getNextDelegateId();
        uint256 returnedFullId = waveCore.findDelegateId(fuzzedMinRequiredVotes, false);
        assertEq(expectedFullId, returnedFullId);
        address returnedFullDelegate = waveCore.getDelegateAddress(returnedFullId);
        assertEq(nounsTokenHarness.getCurrentVotes(returnedFullDelegate), 0);
    }
}
