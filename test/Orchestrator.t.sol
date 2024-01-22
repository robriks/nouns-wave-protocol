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
    address someReallyOldGnosisSafe;
    address[] ownersOfOldSafe;

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
        anotherTokenId = 931;
        // top multisig Nouns holder lol
        someReallyOldGnosisSafe = 0x2573C60a6D127755aA2DC85e342F7da2378a0Cc5;
        ownersOfOldSafe.push(0x6223Bc5fd16a19bcFAe2281dDE47861CFE1023eE);
        ownersOfOldSafe.push(0x83fCFe8Ba2FEce9578F0BbaFeD4Ebf5E915045B9);
        ownersOfOldSafe.push(0xe8cE6C8E37C61b6b77419eEbD661112C21A3Aff8);
        ownersOfOldSafe.push(0xfC9e8dB5E255439F430e058462360Dd52b87cB4f);

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

    function test_delegateBySigERC1271() public {        
        // construct signature for Safe approvedHash
        bytes memory sig = abi.encodePacked(bytes32(uint256(uint160(ownersOfOldSafe[0]))), bytes32(0), uint8(1));
        // get current nonce
        (bool ret, bytes memory res) = someReallyOldGnosisSafe.call(abi.encodeWithSignature("nonce()", ''));
        uint256 nonce = abi.decode(res, (uint256));
        bytes memory getTransactionHashCall = abi.encodeWithSignature(
            "getTransactionHash(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,uint256)",
            address(orchestrator),
            0,
            abi.encodeWithSignature("delegateBySigERC1271(bytes)", sig),
            uint8(1), // Enum.Operation.DelegateCall
            0,
            0,
            0,
            address(0x0),
            address(0x0),
            nonce
        );
        (, bytes memory result) = someReallyOldGnosisSafe.call(getTransactionHashCall);
        bytes32 hashToApprove = abi.decode(result, (bytes32));
        bytes memory hashToApproveCall = abi.encodeWithSignature("approveHash(bytes32)", hashToApprove);
        
        // owner threshold for this old safe is 4
        for (uint256 i; i < ownersOfOldSafe.length; ++i) {
            vm.prank(ownersOfOldSafe[i]);
            someReallyOldGnosisSafe.call(hashToApproveCall);
        }

        bytes memory sig2 = abi.encodePacked(bytes32(uint256(uint160(ownersOfOldSafe[1]))), bytes32(0), uint8(1));
        bytes memory sig3 = abi.encodePacked(bytes32(uint256(uint160(ownersOfOldSafe[2]))), bytes32(0), uint8(1));
        bytes memory sig4 = abi.encodePacked(bytes32(uint256(uint160(ownersOfOldSafe[3]))), bytes32(0), uint8(1));

        bytes memory execTransactionCall = abi.encodeWithSignature(
            "execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes)",
            address(orchestrator),
            0,
            abi.encodeWithSignature("delegateBySigERC1271(bytes)", sig),
            uint8(1), // Enum.Operation.DelegateCall
            0,
            0,
            0,
            address(0x0),
            address(0x0),
            abi.encodePacked(sig,sig2,sig3,sig4)
        );
        someReallyOldGnosisSafe.call(execTransactionCall);
    }

    // function test_purgeInactiveDelegations() public {}

    // if nounder accumulates tokens, orchestrator should reflect
    function test_checkpointChange() public {
        vm.startPrank(someNounHolder);
        nounsToken.transferFrom(someNounHolder, someNounHolder, someTokenId);
    }

    // function test_pushProposal() public {
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
