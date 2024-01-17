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

    // address public alligator; // todo: decide if dep is relevant
    Orchestrator public orchestrator;
    NounsDAOLogicV3 public nounsGovernorProxy;
    NounsTokenLike public nounsToken;

    address ideaTokenHub;
    address payable nounsGovernor;
    address nounsTokenAddress;
    address someNounHolder; // random Nounder holding 17 Nouns at time of writing
    uint256 someTokenId;
    uint256 anotherTokenId;

    // Nouns proposal configuration
    address[] targets;
    uint256[] values;
    string[] funcSigs;
    bytes[] calldatas;
    string description;

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

        // alligator = 0xb6D1EB1A7BE7d55224bB1942C74a5251E6c9Dab3;

        ideaTokenHub = address(0x0); //todo: integrate ideaTokenHub deployment to tests
        nounsGovernor = payable(address(0x6f3E6272A167e8AcCb32072d08E0957F9c79223d));
        nounsTokenAddress = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;

        orchestrator = new Orchestrator(ideaTokenHub, nounsGovernor, nounsTokenAddress);
        
        nounsToken = NounsTokenLike(orchestrator.nounsToken()); 
        nounsGovernorProxy = NounsDAOLogicV3(orchestrator.nounsGovernor());
        assertEq(address(nounsToken), nounsTokenAddress);
        assertEq(address(nounsGovernorProxy), nounsGovernor);

        // pulled from etherscan for testing
        someNounHolder = 0x13061efe742418c361C840CaFf300dC43AC0AffE;
        someTokenId = 918;
        anotherTokenId = 921;

        // placeholder proposal values
        targets.push(address(0x0));
        values.push(1);
        funcSigs.push('');
        calldatas.push('');
        description = 'test';

        vm.deal(address(this), 1 ether);
    }

    function test_delegateBySig() public {
        // to test signatures in a forked env, tokens must first be transferred to a signer address w/ known privkey
        uint256 privKey = 0xdeadbeef;
        address signer = vm.addr(privKey);
        vm.startPrank(someNounHolder);
        nounsToken.transferFrom(someNounHolder, signer, someTokenId);
        nounsToken.transferFrom(someNounHolder, signer, anotherTokenId);
        vm.stopPrank();

        address delegate = orchestrator.getDelegateAddress(signer);
        bytes32 nounsDomainSeparator = keccak256(
            abi.encode(ERC721Checkpointable(address(nounsToken)).DOMAIN_TYPEHASH(), 
            keccak256(bytes(ERC721Checkpointable(address(nounsToken)).name())), 
            block.chainid, 
            address(nounsToken))
        );
        uint256 nonce = ERC721Checkpointable(address(nounsToken)).nonces(signer);
        uint256 expiry = block.timestamp + 1800;
        bytes32 structHash = keccak256(
            abi.encode(ERC721Checkpointable(address(nounsToken)).DELEGATION_TYPEHASH(), delegate, nonce, expiry)
        );
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', nounsDomainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);

        vm.prank(signer);
        orchestrator.delegateBySig(nonce, expiry, abi.encodePacked(r, s, v));
        assertEq(
            ERC721Checkpointable(address(nounsToken)).delegates(signer), 
            orchestrator.getDelegateAddress(signer)
        );
    }

    // function test_purgeInactiveDelegations() public {}
    // function test_votingPowerChange() public {} // if nounder accumulates tokens, orchestrator should reflect

    // function test_NounsProposeViaDelegate() public {
    //     vm.startPrank(someNounHolder);
    //     ERC721Checkpointable(address(nounsToken)).delegate(address(orchestrator));
    //     vm.stopPrank();
                
    //     // mine a block by rolling forward +1 to satisfy `getPriorVotes()` check 
    //     vm.roll(block.number + 1);

    //     orchestrator.pushProposal(targets, values, funcSigs, calldatas, description); 
    // }

    // function test_NounsProposeViaTransfer() public {
    //     vm.startPrank(someNounHolder);
    //     nounsToken.transferFrom(someNounHolder, address(orchestrator), someTokenId);
    //     nounsToken.transferFrom(someNounHolder, address(orchestrator), anotherTokenId);
    //     vm.stopPrank();

    //     vm.prank(address(orchestrator));
    //     ERC721Checkpointable(address(nounsToken)).delegate(address(type(uint160).max));
        
    //     // mine a block by rolling forward +1 to satisfy `getPriorVotes()` check 
    //     vm.roll(block.number + 1);

    //     orchestrator.pushProposal(targets, values, funcSigs, calldatas, description); 
    // }

    // function test_Alligator() public {
    //     //alligator stuff
    //     // bytes memory createCall = abi.encodeWithSignature("create(address,bool)", 
    //     //     address(this), //someNounHolder, 
    //     //     false
    //     // );
    //     // // alligator.call(createCall);

        
    //     // bytes memory subDelegateCall = abi.encodeWithSignature("subDelegate(address,(uint8,uint8,uint32,uint32,uint16,address),bool)", 
    //     //     address(0x0),
    //     //     Rules({permissions: 0,maxRedelegations: 0, notValidBefore: 0, notValidAfter: 0, blocksBeforeVoteCloses: 0, customRule: address(0x0)}),
    //     //     true 
    //     // );
    //     // vm.prank(someNounHolder);
    //     // (bool r,) = alligator.call(subDelegateCall);
    //     // require(r);

    //     // bytes memory proxyAddressCall = abi.encodeWithSignature("proxyAddress(address)", someNounHolder);
    //     // (, bytes memory ret) = alligator.call(proxyAddressCall);
    //     // address proxy = abi.decode(ret, (address));

    //     address proxy = orchestrator.createDelegate();
        
    //     vm.startPrank(someNounHolder);
    //     ERC721Checkpointable(address(nounsToken)).delegate(proxy);
    //     vm.stopPrank();

    //     // mine a block by rolling forward +1 to satisfy `getPriorVotes()` check 
    //     vm.roll(block.number + 1);

    //     orchestrator.pushProposal(targets, values, funcSigs, calldatas, description); 
    // }
}
