// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {IIdeaTokenHub} from "src/interfaces/IIdeaTokenHub.sol";

/// Simulation Usage:
/// `forge script script/UpdateProposal.s.sol:Deploy --fork-url $MAINNET_RPC_URL --keystore $KS --password $PW --sender $VANITY`

contract Deploy is Script {

    IIdeaTokenHub ideaTokenHub = IIdeaTokenHub(0x000000000088b111eA8679dD42f7D55512fD6bE8);
    IWave waveCore = IWave(0x00000000008DDB753b2dfD31e7127f4094CE5630);

    string path = string.concat(vm.projectRoot(), "/test/helpers/updated-proposal");
    string updatedDescription = vm.readFile(path);

    address proposerDelegate = waveCore.getDelegateAddress(1);
    uint256 ideaId = 1;
    uint256 nounsProposalId = 604;
    string updateMessage = 'Fix broken hosted image URLs';

    function run() external {
        vm.startBroadcast();

        uint96[] memory winningIds = new uint96[](1);
        winningIds[0] = uint96(1);
        string[] memory winningDescriptions = new string[](1);
        string memory originalDescPath = string.concat(vm.projectRoot(), "/test/helpers/original-description");
        winningDescriptions[0] = vm.readFile(originalDescPath);

        // ideaTokenHub.finalizeWave(winningIds, winningDescriptions);
        ProposalTxs memory empty = ProposalTxs(
            new address[](0),
            new uint256[](0),
            new string[](0),
            new bytes[](0)
        );

        IWave.Proposal memory updatedProposal = IWave.Proposal(empty, updatedDescription);
        waveCore.updatePushedProposal(proposerDelegate, ideaId, nounsProposalId, updatedProposal, updateMessage);

        vm.stopBroadcast();
    }
}