// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NounsDAOProxyV3} from "nouns-monorepo/governance/NounsDAOProxyV3.sol";
import {NounsDAOLogicV3} from "nouns-monorepo/governance/NounsDAOLogicV3.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {Orchestrator} from "../src/Orchestrator.sol";

contract OrchestratorTest is Test {
    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    Orchestrator public orchestrator;
    NounsDAOLogicV3 public nounsGovernorProxy;
    NounsTokenLike public nounsToken;

    address someNounHolder; // random Nounder holding 17 Nouns at time of writing
    uint256 someTokenId;
    uint256 anotherTokenId;

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);

        orchestrator = new Orchestrator();
        nounsGovernorProxy = NounsDAOLogicV3(orchestrator.NOUNS_GOVERNOR());
        nounsToken = NounsTokenLike(orchestrator.NOUNS_TOKEN());

        // pulled from etherscan for testing
        someNounHolder = 0x13061efe742418c361C840CaFf300dC43AC0AffE;
        someTokenId = 918;
        anotherTokenId = 921;
    }

    function testPropose() public {
        vm.startPrank(someNounHolder);
        nounsToken.transferFrom(someNounHolder, address(orchestrator), someTokenId);
        nounsToken.transferFrom(someNounHolder, address(orchestrator), anotherTokenId);
        vm.stopPrank();
        
        // mine a block by rolling forward +1 to satisfy `getPriorVotes()` check 
        vm.roll(block.number + 1);

        orchestrator.propose(); 
    }
}
