// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {INounsDescriptorMinimal} from 'nouns-monorepo/interfaces/INounsDescriptorMinimal.sol';
import {INounsSeeder} from 'nouns-monorepo/interfaces/INounsSeeder.sol';
import {IProxyRegistry} from 'nouns-monorepo/external/opensea/IProxyRegistry.sol';
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

contract PropLotTest is Test {

    PropLot propLot;
    NounsDAOLogicV1Harness nounsGovernorV1Impl;
    NounsDAOLogicV3Harness nounsGovernorV3Impl;
    NounsDAOLogicV3Harness nounsGovernorProxy;
    NounsDAOExecutorV2 nounsTimelockImpl;
    NounsDAOExecutorV2 nounsTimelockProxy;
    NounsTokenHarness nounsTokenHarness;
    IdeaTokenHub ideaHub;

    INounsDescriptorMinimal nounsDescriptor_;
    INounsSeeder nounsSeeder_;
    IProxyRegistry nounsProxyRegistry_;

    address nounsDAOSafe_; // a gnosis safe proxy on mainnet, test simulation using `vm.prank`
    address nounsAuctionHouserMinter_; // NounsAuctionHouse.sol, test simulations using `vm.prank`
    address nounsTimelockAdmin_;
    uint256 nounsTimelockDelay_;
    address vetoer_;
    uint256 votingDelay_;
    uint256 votingPeriod_;
    uint256 proposalThresholdBPS_;
    uint256 quorumVotesBPS_;

    NounsDAOV3Proposals.ProposalTxs txs;
    string description;


    function setUp() public {
        // setup Nouns token (harness)
        nounsDAOSafe_ = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
        nounsAuctionHouserMinter_ = 0x830BD73E4184ceF73443C15111a1DF14e495C706;
        nounsDescriptor_ = INounsDescriptorMinimal(0x25fF2FdE7df1A433E09749C952f7e09aD3C27951);
        nounsSeeder_ = INounsSeeder(0xCC8a0FB5ab3C7132c1b2A0109142Fb112c4Ce515);
        nounsProxyRegistry_ = IProxyRegistry(0xa5409ec958C83C3f309868babACA7c86DCB077c1);
        nounsTokenHarness = new NounsTokenHarness(nounsDAOSafe_, nounsAuctionHouserMinter_, nounsDescriptor_, nounsSeeder_, nounsProxyRegistry_);

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
        // upgrade to NounsDAOLogicV3Harness
        vm.prank(address(nounsTimelockProxy));
        NounsDAOProxy(payable(address(nounsGovernorProxy)))._setImplementation(address(nounsGovernorV3Impl));

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
    }

    function test_setUp() public {
        assertEq(address(nounsTokenHarness), address(nounsGovernorProxy.nouns()));
        
        address firstDelegate = propLot.getDelegateAddress(1);
        assertTrue(firstDelegate.code.length > 0);
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
    //function test_getDelegateAddress()
    //function test_createDelegate()
    //function test_setActiveDelegation()
    //function test_computeNounsDelegationDigest
}