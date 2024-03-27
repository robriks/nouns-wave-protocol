// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
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
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IPropLot} from "src/interfaces/IPropLot.sol";
import {PropLot} from "src/PropLot.sol";
import {PropLotHarness} from "test/harness/PropLotHarness.sol";


/// Usage:
///   forge script script/TestnetDeployment.s.sol:Deploy \
///     --keystore $KS --password $PW --sender $sender \
///     --fork-url $RPC_URL --broadcast -vvvv \
///     --verify --etherscan-api-key $ETHERSCAN_API_KEY --verifier-url $ETHERSCAN_ENDPOINT
contract Deploy is Script {
    // for dev control over onchain workings
    address nounsSafeMinterVetoerDescriptorAdmin = 0x5d5d4d04B70BFe49ad7Aac8C4454536070dAf180;
    PropLotHarness propLot;
    IdeaTokenHub ideaTokenHub;

    // nouns ecosystem
    NounsDAOLogicV1Harness nounsGovernorV1Impl;
    NounsDAOLogicV3Harness nounsGovernorV3Impl;
    NounsDAOLogicV3Harness nounsGovernorProxy;
    NounsDAOExecutorV2 nounsTimelockImpl;
    NounsDAOExecutorV2 nounsTimelockProxy;
    IERC721Checkpointable nounsTokenHarness;
    IInflator inflator_;
    INounsArt nounsArt_;
    ISVGRenderer nounsRenderer_;
    INounsDescriptorMinimal nounsDescriptor_;
    INounsSeeder nounsSeeder_;
    IProxyRegistry nounsProxyRegistry_;
    NounsDAOForkEscrow nounsForkEscrow_;

    address nounsDAOSafe_; 
    address nounsAuctionHouserMinter_;
    address nounsTimelockAdmin_;
    uint256 nounsTimelockDelay_;
    address vetoer_;
    uint256 votingDelay_;
    uint256 votingPeriod_;
    uint256 proposalThresholdBPS_;
    uint256 quorumVotesBPS_;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        setUpNounsGovernance(deployerPrivateKey);

        // setup PropLot contracts
        string memory uri = "someURI";
        propLot = new PropLotHarness(
            INounsDAOLogicV3(address(nounsGovernorProxy)), IERC721Checkpointable(address(nounsTokenHarness)), uri
        );
        ideaTokenHub = IdeaTokenHub(propLot.ideaTokenHub());
        console2.logAddress(address(propLot));
        console2.logAddress(address(ideaTokenHub));

        // balances to roughly mirror mainnet
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsForkEscrow_), 265);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(nounsDAOSafe_, 30);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71, 308);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsTokenHarness), 25);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0x65A3870F48B5237f27f674Ec42eA1E017E111D63, 25);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(0x1), 370); // ~rest of missing supply to dummy address

        vm.stopBroadcast();
    }

    function setUpNounsGovernance(uint256 deployerPrivateKey) public virtual {
        // setup Nouns token (harness)
        nounsDAOSafe_ = nounsSafeMinterVetoerDescriptorAdmin;
        nounsAuctionHouserMinter_ = nounsSafeMinterVetoerDescriptorAdmin;

        inflator_ = IInflator(address(new Inflator()));
        // rather than simulate create2, set temporary descriptor address then change to correct one after deployment
        nounsArt_ = INounsArt(address(new NounsArt(vm.addr(deployerPrivateKey), inflator_)));
        nounsRenderer_ = ISVGRenderer(address(new SVGRenderer()));
        nounsDescriptor_ = INounsDescriptorMinimal(address(new NounsDescriptorV2(nounsArt_, nounsRenderer_)));
        // add dummy art and change descriptor to correct address after deployment
        nounsArt_.addBackground("0x0");
        nounsArt_.addBodies("0x0", uint80(1), uint16(1));
        nounsArt_.addAccessories("0x0", uint80(1), uint16(1));
        nounsArt_.addHeads("0x0", uint80(1), uint16(1));
        nounsArt_.addGlasses("0x0", uint80(1), uint16(1));
        nounsArt_.setDescriptor(address(nounsDescriptor_));

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
            NounsDAOExecutorV2(payable(address(new NounsDAOExecutorProxy(address(nounsTimelockImpl),  bytes('')))));
        nounsTimelockAdmin_ = nounsSafeMinterVetoerDescriptorAdmin;
        nounsTimelockDelay_ = 1;
        nounsTimelockProxy.initialize(nounsTimelockAdmin_, nounsTimelockDelay_);

        // setup Nouns Governor (harness)
        vetoer_ = nounsSafeMinterVetoerDescriptorAdmin; 
        votingPeriod_ = 600;
        votingDelay_ = 60;
        proposalThresholdBPS_ = 25;
        quorumVotesBPS_ = 1000;
        nounsGovernorV1Impl = new NounsDAOLogicV1Harness(); // will be upgraded to v3
        nounsGovernorProxy = NounsDAOLogicV3Harness(
            payable(
                address(
                    new NounsDAOProxy(
                        address(nounsTimelockProxy),
                        address(nounsTokenHarness),
                        vetoer_,
                        nounsSafeMinterVetoerDescriptorAdmin,
                        address(nounsGovernorV1Impl),
                        votingPeriod_,
                        votingDelay_,
                        proposalThresholdBPS_,
                        quorumVotesBPS_
                    )
                )
            )
        );
        nounsGovernorV3Impl = new NounsDAOLogicV3Harness();

        nounsForkEscrow_ = new NounsDAOForkEscrow(nounsDAOSafe_, address(nounsTokenHarness));
        // upgrade to NounsDAOLogicV3Harness and set nounsForkEscrow
        NounsDAOProxy(payable(address(nounsGovernorProxy)))._setImplementation(address(nounsGovernorV3Impl));
        nounsGovernorProxy._setForkEscrow(address(nounsForkEscrow_));
    }
}