// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NounsDAOProxyV3} from "nouns-monorepo/governance/NounsDAOProxyV3.sol";
import {NounsDAOLogicV3} from "nouns-monorepo/governance/NounsDAOLogicV3.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {ERC721Checkpointable} from "nouns-monorepo/base/ERC721Checkpointable.sol";
import {Orchestrator} from "../src/Orchestrator.sol";

contract OrchestratorTest is Test {
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    address public alligator; // todo: add dep
    Orchestrator public orchestrator;
    NounsDAOLogicV3 public nounsGovernorProxy;
    NounsTokenLike public nounsToken;

    address someNounHolder; // random Nounder holding 17 Nouns at time of writing
    uint256 someTokenId;
    uint256 anotherTokenId;

    struct Rules {
        uint8 permissions;
        uint8 maxRedelegations;
        uint32 notValidBefore;
        uint32 notValidAfter;
        uint16 blocksBeforeVoteCloses;
        address customRule;
    }

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        alligator = 0xb6D1EB1A7BE7d55224bB1942C74a5251E6c9Dab3;

        orchestrator = new Orchestrator();
        nounsGovernorProxy = NounsDAOLogicV3(orchestrator.NOUNS_GOVERNOR());
        nounsToken = NounsTokenLike(orchestrator.NOUNS_TOKEN());

        // pulled from etherscan for testing
        someNounHolder = 0x13061efe742418c361C840CaFf300dC43AC0AffE;
        someTokenId = 918;
        anotherTokenId = 921;
    }

    function test_Alligator() public {
        //alligator stuff
        // bytes memory createCall = abi.encodeWithSignature("create(address,bool)", 
        //     address(this), //someNounHolder, 
        //     false
        // );
        // // alligator.call(createCall);

        
        // bytes memory subDelegateCall = abi.encodeWithSignature("subDelegate(address,(uint8,uint8,uint32,uint32,uint16,address),bool)", 
        //     address(0x0),
        //     Rules({permissions: 0,maxRedelegations: 0, notValidBefore: 0, notValidAfter: 0, blocksBeforeVoteCloses: 0, customRule: address(0x0)}),
        //     true 
        // );
        // vm.prank(someNounHolder);
        // (bool r,) = alligator.call(subDelegateCall);
        // require(r);

        // bytes memory proxyAddressCall = abi.encodeWithSignature("proxyAddress(address)", someNounHolder);
        // (, bytes memory ret) = alligator.call(proxyAddressCall);
        // address proxy = abi.decode(ret, (address));

        address proxy = orchestrator.createDelegate();
        
        vm.startPrank(someNounHolder);
        ERC721Checkpointable(address(nounsToken)).delegate(proxy);
        vm.stopPrank();

        // mine a block by rolling forward +1 to satisfy `getPriorVotes()` check 
        vm.roll(block.number + 1);

        orchestrator.propose(); 
    }

    function test_NounsProposeViaDelegate() public {
        vm.startPrank(someNounHolder);
        ERC721Checkpointable(address(nounsToken)).delegate(address(orchestrator));
        vm.stopPrank();
                
        // mine a block by rolling forward +1 to satisfy `getPriorVotes()` check 
        vm.roll(block.number + 1);

        orchestrator.propose(); 
    }

    function test_NounsProposeViaTransfer() public {
        vm.startPrank(someNounHolder);
        nounsToken.transferFrom(someNounHolder, address(orchestrator), someTokenId);
        nounsToken.transferFrom(someNounHolder, address(orchestrator), anotherTokenId);
        vm.stopPrank();

        vm.prank(address(orchestrator));
        ERC721Checkpointable(address(nounsToken)).delegate(address(type(uint160).max));
        
        // mine a block by rolling forward +1 to satisfy `getPriorVotes()` check 
        vm.roll(block.number + 1);

        orchestrator.propose(); 
    }
}
