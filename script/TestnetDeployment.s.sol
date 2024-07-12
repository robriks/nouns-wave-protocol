// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Inflator} from "nouns-monorepo/Inflator.sol";
import {SVGRenderer} from "nosuns-monorepo/SVGRenderer.sol";
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
import {NounsDAOExecutorProxy} from "nouns-monorepo/governance/NounsDAOExecutorProxy.sol";
import {NounsDAOLogicV1Harness} from "nouns-monorepo/test/NounsDAOLogicV1Harness.sol";
import {NounsDAOLogicV3Harness} from "nouns-monorepo/test/NounsDAOLogicV3Harness.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {Renderer} from "src/SVG/Renderer.sol";
import {FontRegistry} from "FontRegistry/src/FontRegistry.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Wave} from "src/Wave.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";
import {NounsDAOExecutorV2Testnet} from "test/harness/NounsDAOExecutorV2Testnet.sol";

/// Usage:
/// `forge script script/TestnetDeployment.s.sol:Deploy --fork-url $BASE_SEPOLIA_RPC_URL --private-key $PK --with-gas-price 1000000 --verify --etherscan-api-key $BASESCAN_API_KEY --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --broadcast`

/// Verification:
/* 
`forge verify-contract <ideaTokenHub> --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --watch --etherscan-api-key $BASESCAN_API_KEY src/IdeaTokenHub.sol:IdeaTokenHub`
`forge verify-contract <waveCore> --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --watch --etherscan-api-key $BASESCAN_API_KEY test/harness/WaveHarness.sol:WaveHarness`
`forge verify-contract <nounsToken> --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --watch --etherscan-api-key $BASESCAN_API_KEY lib/nouns-monorepo/nouns-contracts/contracts/test/NounsTokenHarness.sol`
*/

contract Deploy is Script {
    // for dev control over onchain workings
    address nounsSafeMinterVetoerDescriptorAdmin = 0x5d5d4d04B70BFe49ad7Aac8C4454536070dAf180;
    address frog = 0x65A3870F48B5237f27f674Ec42eA1E017E111D63;
    address vanity = 0xFFFFfFfFA2eC6F66a22017a0Deb0191e5F8cBc35;
    uint256 minSponsorshipAmount = 1 wei; // TESTNET ONLY
    uint256 waveLength = 150; // TESTNET ONLY

    /// @notice Harness contract is used on testnet ONLY
    WaveHarness waveCoreImpl;
    WaveHarness waveCore;
    IdeaTokenHub ideaTokenHubImpl;
    IdeaTokenHub ideaTokenHub;
    FontRegistry fontRegistry;
    Renderer renderer;

    // nouns ecosystem
    NounsDAOLogicV1Harness nounsGovernorV1Impl;
    NounsDAOLogicV3Harness nounsGovernorV3Impl;
    NounsDAOLogicV3Harness nounsGovernorProxy;
    NounsDAOExecutorV2Testnet nounsTimelockImpl;
    NounsDAOExecutorV2Testnet nounsTimelockProxy;
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

        // setup Nouns env
        _deployNounsInfra(deployerPrivateKey);

        // setup Wave contracts
        fontRegistry = new FontRegistry();
        renderer = new Renderer(address(fontRegistry));

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

        require(address(fontRegistry).code.length > 0);
        require(address(renderer).code.length > 0);
        require(address(ideaTokenHub).code.length > 0);
        require(address(waveCore).code.length > 0);
        require(address(nounsTokenHarness).code.length > 0);
        console2.logAddress(address(fontRegistry));
        console2.logAddress(address(renderer));
        console2.logAddress(address(ideaTokenHub));
        console2.logAddress(address(waveCore));
        console2.logAddress(address(nounsTokenHarness));

        // balances to roughly mirror mainnet
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsForkEscrow_), 130); // must be split into 2 transactions
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsForkEscrow_), 135); // due to inefficiency & block gas limit
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(nounsDAOSafe_, 30); // == deployer
        // must be split into 2 transactions due to inefficiency & block gas limit
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71, 150);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71, 150);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(address(nounsTokenHarness), 25);
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(frog, 25);
        // must be split into 2 transactions due to inefficiency & block gas limit
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(vanity, 150); // ~rest of missing supply to dummy address
        NounsTokenHarness(address(nounsTokenHarness)).mintMany(vanity, 150); // ~rest of missing supply to dummy address

        vm.stopBroadcast();
    }

    function _deployNounsInfra(uint256 _deployerPrivateKey) internal {
        nounsDAOSafe_ = nounsSafeMinterVetoerDescriptorAdmin;
        nounsAuctionHouserMinter_ = nounsSafeMinterVetoerDescriptorAdmin;

        inflator_ = IInflator(address(new Inflator()));
        // rather than simulate create2, set temporary descriptor address then change to correct one after deployment
        nounsArt_ = INounsArt(address(new NounsArt(vm.addr(_deployerPrivateKey), inflator_)));
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
        nounsTimelockImpl = new NounsDAOExecutorV2Testnet();
        nounsTimelockProxy = NounsDAOExecutorV2Testnet(
            payable(address(new NounsDAOExecutorProxy(address(nounsTimelockImpl), bytes(""))))
        );
        nounsTimelockAdmin_ = nounsSafeMinterVetoerDescriptorAdmin;
        nounsTimelockDelay_ = 1;
        nounsTimelockProxy.initialize(nounsTimelockAdmin_, nounsTimelockDelay_);

        // setup Nouns Governor (harness)
        vetoer_ = nounsSafeMinterVetoerDescriptorAdmin;
        votingPeriod_ = 5; // 1 minute voting period in blocks
        votingDelay_ = 1; // 12 second voting delay in blocks
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
