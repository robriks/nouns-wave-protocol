// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsTokenHarness} from "nouns-monorepo/test/NounsTokenHarness.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {IdeaTokenHub} from "src/IdeaTokenHub.sol";
import {Delegate} from "src/Delegate.sol";
import {IPropLot} from "src/interfaces/IPropLot.sol";
import {PropLot} from "src/PropLot.sol";
import {PropLotHarness} from "test/harness/PropLotHarness.sol";

contract CreateIdeas is Script {
    PropLotHarness propLot;
    IdeaTokenHub ideaTokenHub;

    string uri;
    NounsDAOV3Proposals.ProposalTxs txs;
    string description;
    IPropLot.Proposal[] proposals;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        uri = "someURI";
        propLot = PropLotHarness(0xfDc4512f88046609eDfD3624d07814b1cee05d48);
        ideaTokenHub = IdeaTokenHub(propLot.ideaTokenHub());

        // setup mock proposal
        txs.targets.push(address(0x0));
        txs.values.push(1);
        txs.signatures.push("");
        txs.calldatas.push("");
        description = "test";

        // ideaTokenHub.createIdea{value: 0.0001 ether}(txs, description);
        ideaTokenHub.sponsorIdea{value: 0.0001 ether}(1);
        vm.stopBroadcast();
    }
}