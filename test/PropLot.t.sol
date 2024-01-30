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
import {NounsDAOLogicV3Harness} from "nouns-monorepo/test/NounsDAOLogicV3Harness.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {ERC721Checkpointable} from "nouns-monorepo/base/ERC721Checkpointable.sol";
import {PropLot} from "../src/PropLot.sol";
import {IdeaTokenHub} from "../src/IdeaTokenHub.sol";

contract PropLotTest is Test {

    PropLot propLot;
    NounsDAOLogicV3Harness nounsGovernorImpl;
    NounsDAOLogicV3Harness nounsGovernorProxy;
    NounsDAOExecutorV2 nounsTimelockImpl;
    NounsDAOExecutorV2 nounsTimelockProxy;
    NounsTokenHarness nounsTokenHarness;
    IdeaTokenHub ideaHub;

    INounsDescriptorMinimal nounsDescriptor_;
    INounsSeeder nounsSeeder_;
    IProxyRegistry nounsProxyRegistry_;

    address nounsDAO_;
    address nounsAuctionHouserMinter_;
    address nounsTimelockAdmin_;
    uint256 nounsTimelockDelay_;
    address vetoer_;

    NounsDAOV3Proposals.ProposalTxs txs;


    function setUp() public {
        nounsDAO_ = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
        nounsAuctionHouserMinter_ = 0x830BD73E4184ceF73443C15111a1DF14e495C706;
        nounsDescriptor_ = INounsDescriptorMinimal(0x25fF2FdE7df1A433E09749C952f7e09aD3C27951);
        nounsSeeder_ = INounsSeeder(0xCC8a0FB5ab3C7132c1b2A0109142Fb112c4Ce515);
        nounsProxyRegistry_ = IProxyRegistry(0xa5409ec958C83C3f309868babACA7c86DCB077c1);
        nounsTokenHarness = new NounsTokenHarness(nounsDAO_, nounsAuctionHouserMinter_, nounsDescriptor_, nounsSeeder_, nounsProxyRegistry_);

        nounsTimelockAdmin_ = 0x6f3E6272A167e8AcCb32072d08E0957F9c79223d;
        nounsTimelockDelay_ = 172800;
        nounsTimelockImpl = new NounsDAOExecutorV2(nounsTimelockAdmin_, nounsTimelockDelay_);
        nounsTimelockProxy = NounsDAOExecutorV2(address(new NounsDAOExecutorProxy(address(nounsTimelockImpl),'')));

        vetoer_ = vm.addr(0xdeadbeef); // gnosis safe on mainnet
        nounsGovernorImpl = new NounsDAOLogicV3Harness();
        nounsGovernorProxy = 
            NounsDAOLogicV3Harness(
                address(new NounsDAOProxy(
                    address(nounsTimelockProxy),
                    address(nounsTokenHarness),
                    vetoer_,
                    address(nounsTimelockProxy), // admin == timelock
                    address(nounsGovernorImpl),
                    votingPeriod_,
                    votingDelay_,
                    proposalThresholdBPS_,
                    quorumVoteBPS_
                )));
        ideaHub = new IdeaTokenHub();
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