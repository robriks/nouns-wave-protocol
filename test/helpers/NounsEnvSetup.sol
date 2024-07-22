// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {Inflator} from "nouns-monorepo/Inflator.sol";
import {SVGRenderer} from "nouns-monorepo/SVGRenderer.sol";
import {NounsArt} from "nouns-monorepo/NounsArt.sol";
import {NounsDescriptorV2} from "nouns-monorepo/NounsDescriptorV2.sol";
import {NounsSeeder} from "nouns-monorepo/NounsSeeder.sol";
import {IInflator} from "nouns-monorepo/interfaces/IInflator.sol";
import {ISVGRenderer} from "nouns-monorepo/interfaces/ISVGRenderer.sol";
import {INounsArt} from "nouns-monorepo/interfaces/INounsArt.sol";
import {INounsDescriptorMinimal} from "nouns-monorepo/interfaces/INounsDescriptorMinimal.sol";
import {INounsSeeder} from "nouns-monorepo/interfaces/INounsSeeder.sol";
import {IProxyRegistry} from "nouns-monorepo/external/opensea/IProxyRegistry.sol";
import {ProxyRegistryMock} from "nouns-monorepo/../test/foundry/helpers/ProxyRegistryMock.sol";
import {NounsDAOForkEscrow} from "nouns-monorepo/governance/fork/NounsDAOForkEscrow.sol";
import {NounsDAOProxyV3} from "nouns-monorepo/governance/NounsDAOProxyV3.sol";
import {NounsDAOExecutorV2} from "nouns-monorepo/governance/NounsDAOExecutorV2.sol";
import {NounsDAOExecutorProxy} from "nouns-monorepo/governance/NounsDAOExecutorProxy.sol";
import {NounsDAOLogicV3Harness} from "nouns-monorepo/test/NounsDAOLogicV3Harness.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike, NounsDAOTypes} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV4} from "src/interfaces/INounsDAOLogicV4.sol";

/// @dev Clones Nouns infrastructure from mainnet to a testing environment

struct NounsConfigData {
    uint40 decompressedLengthOfHeadBytes;
    bytes encodedCompressedHeadsData; 
    uint16 imageCountOfHeads;
    bytes palette0;
}

contract NounsEnvSetup is Test {
    NounsDAOLogicV3Harness nounsGovernorV3Impl;
    INounsDAOLogicV4 nounsGovernorProxy;
    NounsDAOExecutorV2 nounsTimelockImpl;
    NounsDAOExecutorV2 nounsTimelockProxy;
    IERC721Checkpointable nounsTokenHarness;
    IInflator inflator_;
    INounsArt nounsArt_;
    ISVGRenderer nounsRenderer_;
    NounsDescriptorV2 nounsDescriptor_;
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
    uint32 lastMinuteWindowInBlocks_;
    uint32 objectionPeriodDurationInBlocks_;
    uint32 proposalUpdatablePeriodInBlocks_;
    uint32 fromBlock_;
    uint16 minQuorumVotesBPS_;
    uint16 maxQuorumVotesBPS_;
    uint32 quorumCoefficient_;

    function setUpNounsGovernance() public virtual {
        // setup Nouns token (harness)
        nounsDAOSafe_ = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
        nounsAuctionHouserMinter_ = 0x830BD73E4184ceF73443C15111a1DF14e495C706;

        inflator_ = IInflator(address(new Inflator()));
        nounsRenderer_ = ISVGRenderer(address(new SVGRenderer()));
        // rather than simulate create2, set temporary descriptor address then change to correct one after deployment
        nounsArt_ = INounsArt(address(new NounsArt(vm.addr(0xd00d00), inflator_)));
        nounsDescriptor_ = new NounsDescriptorV2(nounsArt_, nounsRenderer_);
        vm.prank(vm.addr(0xd00d00));
        nounsArt_.setDescriptor(address(nounsDescriptor_));

        // testnet descriptor requires palette and head to be set to match mainnet
        string memory root = vm.projectRoot();
        string memory nounsConfigDataPath = string.concat(root, "/test/helpers/nouns-config-data.json");
        string memory nounsConfigDataJson = vm.readFile(nounsConfigDataPath);
        NounsConfigData memory configData = abi.decode(vm.parseJson(nounsConfigDataJson), (NounsConfigData));
                
        nounsDescriptor_.setPalette(0, configData.palette0);
        nounsDescriptor_.addHeads(configData.encodedCompressedHeadsData, configData.decompressedLengthOfHeadBytes, configData.imageCountOfHeads);

        // add dummy art configs as descriptor
        vm.startPrank(address(nounsDescriptor_));
        nounsArt_.addBackground("");
        nounsArt_.addBodies("0x0", uint80(1), uint16(1));
        nounsArt_.addAccessories("0x0", uint80(1), uint16(1));
        nounsArt_.addGlasses("0x0", uint80(1), uint16(1));
        vm.stopPrank();

        nounsSeeder_ = INounsSeeder(address(new NounsSeeder()));
        nounsProxyRegistry_ = IProxyRegistry(address(new ProxyRegistryMock()));
        nounsTokenHarness = IERC721Checkpointable(
            address(
                new NounsTokenHarness(
                    nounsDAOSafe_, nounsAuctionHouserMinter_, nounsDescriptor_, nounsSeeder_, nounsProxyRegistry_
                )
            )
        );

        // setup Nouns timelock executor
        nounsTimelockImpl = new NounsDAOExecutorV2();
        nounsTimelockProxy =
            NounsDAOExecutorV2(payable(address(new NounsDAOExecutorProxy(address(nounsTimelockImpl), ""))));

        // setup Nouns Governor (harness)
        vetoer_ = vm.addr(0xdeadbeef); // gnosis safe on mainnet
        votingPeriod_ = 28800;
        votingDelay_ = 3600;
        proposalThresholdBPS_ = 25;
        lastMinuteWindowInBlocks_ = 0;
        objectionPeriodDurationInBlocks_ = 0;
        proposalUpdatablePeriodInBlocks_ = 18000;
        fromBlock_ = 20000000; // recentish block
        minQuorumVotesBPS_ = 1000;
        maxQuorumVotesBPS_ = 1500;
        quorumCoefficient_ = 1000000;

        nounsGovernorV3Impl = new NounsDAOLogicV3Harness();
        nounsGovernorProxy = INounsDAOLogicV4(
            payable(
                address(
                    new NounsDAOProxyV3(
                        address(nounsTimelockProxy),
                        address(nounsTokenHarness),
                        address(nounsForkEscrow_),
                        nounsDAOSafe_, // `forkDAODeployer` not used, set to filler address
                        vetoer_,
                        address(nounsTimelockProxy), // admin == timelock
                        address(nounsGovernorV3Impl),
                        NounsDAOTypes.NounsDAOParams(
                            votingPeriod_,
                            votingDelay_,
                            proposalThresholdBPS_,
                            lastMinuteWindowInBlocks_,
                            objectionPeriodDurationInBlocks_,
                            proposalUpdatablePeriodInBlocks_
                        ),
                        NounsDAOTypes.DynamicQuorumParams(
                            minQuorumVotesBPS_,
                            maxQuorumVotesBPS_,
                            quorumCoefficient_
                        )
                    )
                )
            )
        );

        nounsTimelockAdmin_ = address(nounsGovernorProxy);
        nounsTimelockDelay_ = 172800;
        nounsTimelockProxy.initialize(nounsTimelockAdmin_, nounsTimelockDelay_);

        nounsForkEscrow_ = new NounsDAOForkEscrow(nounsDAOSafe_, address(nounsTokenHarness));
        // set nounsForkEscrow
        vm.prank(address(nounsTimelockProxy));
        nounsGovernorProxy._setForkEscrow(address(nounsForkEscrow_));
    }

    function mintMirrorBalances() public {
        // mint balances to roughly mirror mainnet
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsForkEscrow_), 265);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(nounsDAOSafe_, 30);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71, 308);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsTokenHarness), 25);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(0x1), 370); // ~rest of missing supply to dummy address
    }
}