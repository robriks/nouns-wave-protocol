// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Inflator} from "nouns-monorepo/Inflator.sol";
import {SVGRenderer} from "nouns-monorepo/SVGRenderer.sol";
import {NounsArt} from "nouns-monorepo/NounsArt.sol";
import {NounsDescriptorV2} from "nouns-monorepo/NounsDescriptorV2.sol";
import {NounsSeeder} from "nouns-monorepo/NounsSeeder.sol";
import {IInflator} from "nouns-monorepo/interfaces/IInflator.sol";
import {INounsArt} from "nouns-monorepo/interfaces/INounsArt.sol";
import {INounsSeeder} from "nouns-monorepo/interfaces/INounsSeeder.sol";
import {IProxyRegistry} from "nouns-monorepo/external/opensea/IProxyRegistry.sol";
import {ProxyRegistryMock} from "nouns-monorepo/../test/foundry/helpers/ProxyRegistryMock.sol";
import {NounsDAOForkEscrow} from "nouns-monorepo/governance/fork/NounsDAOForkEscrow.sol";
import {NounsDAOProxyV3} from "nouns-monorepo/governance/NounsDAOProxyV3.sol";
import {NounsDAOExecutorProxy} from "nouns-monorepo/governance/NounsDAOExecutorProxy.sol";
import {NounsDAOLogicV3Harness} from "nouns-monorepo/test/NounsDAOLogicV3Harness.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike, NounsDAOTypes} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {INounsDAOLogicV4} from "src/interfaces/INounsDAOLogicV4.sol";
import {Renderer} from "src/SVG/Renderer.sol";
import {PolymathTextRegular} from "src/SVG/fonts/PolymathTextRegular.sol";
import {IPolymathTextRegular} from "src/SVG/fonts/IPolymathTextRegular.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Wave} from "src/Wave.sol";
import {WaveHarness} from "test/harness/WaveHarness.sol";
import {NounsDAOExecutorV2Testnet} from "test/harness/NounsDAOExecutorV2Testnet.sol";
import {NounsConfigData} from "test/helpers/NounsEnvSetup.sol";
import {Font} from "test/svg/HotChainSVG.t.sol";

/// Usage:
/// `forge script script/TestnetDeployment.s.sol:Deploy --fork-url $BASE_SEPOLIA_RPC_URL --private-key $PK --with-gas-price 1000000 --verify --etherscan-api-key $BASESCAN_API_KEY --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --broadcast`

/// Verification:
/* 
`forge verify-contract <ideaTokenHub> --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --watch --etherscan-api-key $BASESCAN_API_KEY src/IdeaTokenHub.sol:IdeaTokenHub`
`forge verify-contract <waveCore> --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --watch --etherscan-api-key $BASESCAN_API_KEY test/harness/WaveHarness.sol:WaveHarness`
`forge verify-contract <nounsToken> --verifier-url $BASESCAN_SEPOLIA_ENDPOINT --watch --etherscan-api-key $BASESCAN_API_KEY lib/nouns-monorepo/packages/nouns-contracts/contracts/test/NounsTokenHarness.sol`
*/

contract Deploy is Script {
    // for dev control over onchain workings
    address nounsSafeMinterVetoerDescriptorAdmin = 0x5d5d4d04B70BFe49ad7Aac8C4454536070dAf180;
    address frog = 0x65A3870F48B5237f27f674Ec42eA1E017E111D63;
    address vanity = 0xFFFFfFfFA2eC6F66a22017a0Deb0191e5F8cBc35;
    uint256 minSponsorshipAmount = 1 wei; // TESTNET ONLY
    uint256 waveLength = 150; // TESTNET ONLY
    string polyText;

    /// @notice Harness contract is used on testnet ONLY
    WaveHarness waveCoreImpl;
    WaveHarness waveCore;
    IdeaTokenHub ideaTokenHubImpl;
    IdeaTokenHub ideaTokenHub;
    Renderer renderer;
    IPolymathTextRegular polymathTextRegular;

    // nouns ecosystem
    NounsDAOLogicV3Harness nounsGovernorV3Impl;
    INounsDAOLogicV4 nounsGovernorProxy;
    NounsDAOExecutorV2Testnet nounsTimelockImpl;
    NounsDAOExecutorV2Testnet nounsTimelockProxy;
    IERC721Checkpointable nounsTokenHarness;
    SVGRenderer nounsRenderer;
    NounsDescriptorV2 nounsDescriptor;
    IInflator inflator_;
    INounsArt nounsArt_;
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
    uint32 lastMinuteWindowInBlocks_;
    uint32 objectionPeriodDurationInBlocks_;
    uint32 proposalUpdatablePeriodInBlocks_;
    uint32 fromBlock_;
    uint16 minQuorumVotesBPS_;
    uint16 maxQuorumVotesBPS_;
    uint32 quorumCoefficient_;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // setup Nouns env
        string memory root = vm.projectRoot();
        _deployNounsInfra(deployerPrivateKey, root);

        // deploy PolymathText font and provide it to Renderer constructor on deployment
        string memory fontPath = string.concat(root, "/test/helpers/font.json");
        string memory fontJson = vm.readFile(fontPath);
        Font memory polyFont = abi.decode(vm.parseJson(fontJson), (Font));
        polyText = polyFont.data;
        polymathTextRegular = IPolymathTextRegular(address(new PolymathTextRegular(polyText)));

        renderer = new Renderer(polymathTextRegular, address(nounsDescriptor), address(nounsRenderer));

        // deploy Wave protocol contracts
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

        require(address(polymathTextRegular).code.length > 0);
        require(address(renderer).code.length > 0);
        require(address(polymathTextRegular).code.length > 0);
        require(address(ideaTokenHub).code.length > 0);
        require(address(waveCore).code.length > 0);
        require(address(nounsTokenHarness).code.length > 0);
        console2.logAddress(address(polymathTextRegular));
        console2.logAddress(address(renderer));
        console2.logAddress(address(polymathTextRegular));
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

    function _deployNounsInfra(uint256 _deployerPrivateKey, string memory _root) internal {
        nounsDAOSafe_ = nounsSafeMinterVetoerDescriptorAdmin;
        nounsAuctionHouserMinter_ = nounsSafeMinterVetoerDescriptorAdmin;

        inflator_ = IInflator(address(new Inflator()));
        // rather than simulate create2, set temporary descriptor address then change to correct one after deployment
        nounsArt_ = INounsArt(address(new NounsArt(vm.addr(_deployerPrivateKey), inflator_)));
        nounsRenderer = new SVGRenderer();
        nounsDescriptor = new NounsDescriptorV2(nounsArt_, nounsRenderer);

        // testnet descriptor requires palette and head to be set to match mainnet
        string memory nounsConfigDataPath = string.concat(_root, "/test/helpers/nouns-config-data.json");
        string memory nounsConfigDataJson = vm.readFile(nounsConfigDataPath);
        NounsConfigData memory configData = abi.decode(vm.parseJson(nounsConfigDataJson), (NounsConfigData));
                
        nounsDescriptor.setPalette(0, configData.palette0);
        nounsDescriptor.addHeads(configData.encodedCompressedHeadsData, configData.decompressedLengthOfHeadBytes, configData.imageCountOfHeads);

        // add dummy art and change descriptor to correct address after deployment
        nounsArt_.addBackground("0x0");
        nounsArt_.addBodies("0x0", uint80(1), uint16(1));
        nounsArt_.addAccessories("0x0", uint80(1), uint16(1));
        nounsArt_.addGlasses("0x0", uint80(1), uint16(1));
        nounsArt_.setDescriptor(address(nounsDescriptor));

        nounsSeeder_ = INounsSeeder(address(new NounsSeeder()));
        nounsProxyRegistry_ = IProxyRegistry(address(new ProxyRegistryMock()));
        nounsTokenHarness = IERC721Checkpointable(
            address(
                new NounsTokenHarness(
                    nounsDAOSafe_, nounsAuctionHouserMinter_, nounsDescriptor, nounsSeeder_, nounsProxyRegistry_
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

        nounsForkEscrow_ = new NounsDAOForkEscrow(nounsDAOSafe_, address(nounsTokenHarness));
        // set nounsForkEscrow
        nounsGovernorProxy._setForkEscrow(address(nounsForkEscrow_));
    }
}