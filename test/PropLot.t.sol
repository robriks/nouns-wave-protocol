// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Inflator} from "nouns-monorepo/Inflator.sol";
import {SVGRenderer} from "nouns-monorepo/SVGRenderer.sol";
import {NounsArt} from "nouns-monorepo/NounsArt.sol";
import {NounsDescriptorV2} from "nouns-monorepo/NounsDescriptorV2.sol";
import {NounsSeeder} from "nouns-monorepo/NounsSeeder.sol";
import {IInflator} from "nouns-monorepo/interfaces/IInflator.sol";
import {ISVGRenderer} from "nouns-monorepo/interfaces/ISVGRenderer.sol";
import {INounsArt} from "nouns-monorepo/interfaces/INounsArt.sol";
import {INounsDescriptorMinimal} from 'nouns-monorepo/interfaces/INounsDescriptorMinimal.sol';
import {INounsSeeder} from 'nouns-monorepo/interfaces/INounsSeeder.sol';
import {IProxyRegistry} from 'nouns-monorepo/external/opensea/IProxyRegistry.sol';
import {NounsDAOForkEscrow} from "nouns-monorepo/governance/fork/NounsDAOForkEscrow.sol";
import {NounsDAOProxy} from "nouns-monorepo/governance/NounsDAOProxy.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsDAOExecutorV2} from "nouns-monorepo/governance/NounsDAOExecutorV2.sol";
import {NounsDAOExecutorProxy} from "nouns-monorepo/governance/NounsDAOExecutorProxy.sol";
import {NounsDAOLogicV1Harness} from "nouns-monorepo/test/NounsDAOLogicV1Harness.sol";
import {NounsDAOLogicV3Harness} from "nouns-monorepo/test/NounsDAOLogicV3Harness.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {PropLot} from "src/PropLot.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";

/// @notice Fuzz iteration params can be increased to larger types to match implementation
/// They are temporarily set to smaller types for speed only
contract PropLotTest is Test {

    PropLot propLot;
    NounsDAOLogicV1Harness nounsGovernorV1Impl;
    NounsDAOLogicV3Harness nounsGovernorV3Impl;
    NounsDAOLogicV3Harness nounsGovernorProxy;
    NounsDAOExecutorV2 nounsTimelockImpl;
    NounsDAOExecutorV2 nounsTimelockProxy;
    IERC721Checkpointable nounsTokenHarness;
    IdeaTokenHub ideaHub;

    IInflator inflator_;
    INounsArt nounsArt_;
    ISVGRenderer nounsRenderer_;
    INounsDescriptorMinimal nounsDescriptor_;
    INounsSeeder nounsSeeder_; // 0xCC8a0FB5ab3C7132c1b2A0109142Fb112c4Ce515
    IProxyRegistry nounsProxyRegistry_;
    NounsDAOForkEscrow nounsForkEscrow_;

    address nounsDAOSafe_; // 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5 gnosis safe proxy, test via `vm.prank`
    address nounsAuctionHouserMinter_; // 0x830BD73E4184ceF73443C15111a1DF14e495C706 NounsAuctionHouse.sol, test via `vm.prank`
    address nounsTimelockAdmin_;
    uint256 nounsTimelockDelay_;
    address vetoer_;
    uint256 votingDelay_;
    uint256 votingPeriod_;
    uint256 proposalThresholdBPS_;
    uint256 quorumVotesBPS_;

    NounsDAOV3Proposals.ProposalTxs txs;
    string description;

    address nounder;

    function setUp() public {
        // setup Nouns token (harness)
        nounsDAOSafe_ = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
        nounsAuctionHouserMinter_ = 0x830BD73E4184ceF73443C15111a1DF14e495C706;
        
        inflator_ = IInflator(address(new Inflator()));
        // rather than simulate create2, set temporary descriptor address then change to correct one after deployment
        nounsArt_ = INounsArt(address(new NounsArt(vm.addr(0xd00d00), inflator_)));
        nounsRenderer_ = ISVGRenderer(address (new SVGRenderer()));
        nounsDescriptor_ = INounsDescriptorMinimal(address(new NounsDescriptorV2(nounsArt_, nounsRenderer_)));
        // add dummy art and change descriptor to correct address after deployment
        vm.startPrank(vm.addr(0xd00d00));
        nounsArt_.addBackground('');
        nounsArt_.addBodies('0x0', uint80(1), uint16(1));
        nounsArt_.addAccessories('0x0', uint80(1), uint16(1));
        nounsArt_.addHeads('0x0', uint80(1), uint16(1));
        nounsArt_.addGlasses('0x0', uint80(1), uint16(1));
        nounsArt_.setDescriptor(address(nounsDescriptor_));
        vm.stopPrank();

        nounsSeeder_ = INounsSeeder(address(new NounsSeeder()));
        nounsProxyRegistry_ = IProxyRegistry(0xa5409ec958C83C3f309868babACA7c86DCB077c1);
        nounsTokenHarness = IERC721Checkpointable(address(new NounsTokenHarness(nounsDAOSafe_, nounsAuctionHouserMinter_, nounsDescriptor_, nounsSeeder_, nounsProxyRegistry_)));

        // setup Nouns timelock executor
        nounsTimelockImpl = new NounsDAOExecutorV2();
        nounsTimelockProxy = NounsDAOExecutorV2(payable(address(new NounsDAOExecutorProxy(address(nounsTimelockImpl),''))));
        nounsTimelockAdmin_ = 0x6f3E6272A167e8AcCb32072d08E0957F9c79223d;
        nounsTimelockDelay_ = 172800;
        nounsTimelockProxy.initialize(nounsTimelockAdmin_, nounsTimelockDelay_);

        // setup Nouns Governor (harness)
        vetoer_ = vm.addr(0xdeadbeef); // gnosis safe on mainnet
        votingPeriod_ = 28800;
        votingDelay_ = 3600;
        proposalThresholdBPS_ = 25;
        quorumVotesBPS_ = 1000;
        nounsGovernorV1Impl = new NounsDAOLogicV1Harness(); // will be upgraded to v3
        nounsGovernorProxy = 
            NounsDAOLogicV3Harness(
                payable(address(
                    new NounsDAOProxy(
                        address(nounsTimelockProxy),
                        address(nounsTokenHarness),
                        vetoer_,
                        address(nounsTimelockProxy), // admin == timelock
                        address(nounsGovernorV1Impl),
                        votingPeriod_,
                        votingDelay_,
                        proposalThresholdBPS_,
                        quorumVotesBPS_
                    )
                ))
            );
        nounsGovernorV3Impl = new NounsDAOLogicV3Harness();
        
        nounsForkEscrow_ = new NounsDAOForkEscrow(nounsDAOSafe_, address(nounsTokenHarness));
        // upgrade to NounsDAOLogicV3Harness and set nounsForkEscrow
        vm.startPrank(address(nounsTimelockProxy));
        NounsDAOProxy(payable(address(nounsGovernorProxy)))._setImplementation(address(nounsGovernorV3Impl));
        nounsGovernorProxy._setForkEscrow(address(nounsForkEscrow_));        
        vm.stopPrank();

        // setup PropLot contracts
        ideaHub = new IdeaTokenHub();
        propLot = new PropLot(address(ideaHub), INounsDAOLogicV3(address(nounsGovernorProxy)), IERC721Checkpointable(address(nounsTokenHarness)));

        // setup mock proposal
        txs.targets.push(address(0x0));
        txs.values.push(1);
        txs.signatures.push('');
        txs.calldatas.push('');
        description = 'test';

        vm.deal(address(this), 1 ether);

        // balances to roughly mirror mainnet
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsForkEscrow_), 265);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(nounsDAOSafe_, 30);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71, 308);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsTokenHarness), 25);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(0x1), 370); // ~rest of missing supply to dummy address
        nounder = vm.addr(0xc0ffeebabe);
        NounsTokenHarness(address(nounsTokenHarness)).mintTo(nounder);
    }

    function test_setUp() public {
        assertEq(address(nounsTokenHarness), address(nounsGovernorProxy.nouns()));
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).balanceOf(nounder), 1);
        
        uint256 totalSupply = NounsTokenHarness(address(nounsTokenHarness)).totalSupply();
        assertEq(NounsTokenHarness(address(nounsTokenHarness)).ownerOf(totalSupply - 1), nounder);
        
        address firstDelegate = propLot.getDelegateAddress(1);
        assertTrue(firstDelegate.code.length > 0);

        uint256 nextDelegateId = propLot.getNextDelegateId();
        assertEq(nextDelegateId, 2);

        uint256 proposalThreshold = nounsGovernorProxy.proposalThreshold();
        uint256 incompleteDelegateId = propLot.getDelegateId(proposalThreshold, true);
        assertEq(incompleteDelegateId, 1);
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

    // function test_getDelegateId()
    // function test_getSoloDelegateId()

    function test_createDelegate(uint8 fuzzIterations) public {
        uint256 startDelegateId = propLot.getNextDelegateId();
        assertEq(startDelegateId, 2);

        for (uint16 i; i < fuzzIterations; ++i) {
            uint256 fuzzDelegateId = startDelegateId + i;
            propLot.createDelegate();
            
            // assert next delegate ID was incremented
            uint256 nextDelegateId = propLot.getNextDelegateId();
            assertEq(fuzzDelegateId + 1, nextDelegateId);
        }
    }

    function test_setActiveDelegation() public {
        // perform external delegation to relevant delegate
        uint256 proposalThreshold = nounsGovernorProxy.proposalThreshold();
        uint256 delegateId = propLot.getDelegateId(proposalThreshold, true);
        address delegate = propLot.getDelegateAddress(delegateId);
        vm.prank(nounder);
        nounsTokenHarness.delegate(delegate);
    }

    function test_revertPushProposalNotIdeaTokenHub() public {
        bytes memory err = abi.encodeWithSelector(PropLot.OnlyIdeaContract.selector);
        vm.expectRevert(err);
        propLot.pushProposal(txs, description);
    }

    function test_revertPushProposalNotPropLot() public {
        Delegate firstDelegate = Delegate(propLot.getDelegateAddress(1));
        
        bytes memory err = abi.encodeWithSelector(Delegate.NotPropLotCore.selector, address(this));
        vm.expectRevert(err);
        firstDelegate.pushProposal(INounsDAOLogicV3(address(nounsGovernorProxy)), txs, description);
    }

    //function test_pushProposal()
    //function test_delegateBySig()
    //function test_delegateByDelegateCall
    //function test_proposalThresholdIncrease()

    //function test_disqualifiedDelegationIndices()
    //function test_deleteDelegations()
    //function test_deleteDelegationsZeroMembers()
    //function test_simulateCreate2()
    //function test_createDelegate()
    //function test_setActiveDelegation()
    //function test_computeNounsDelegationDigest
}