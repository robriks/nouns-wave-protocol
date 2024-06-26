// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";

/// @title Wave Protocol Delegate
/// @author 📯📯📯.eth
/// @notice All Wave Protocol Delegate contracts are managed by the Wave Core. They are designed to receive
/// Nouns token delegation non-custodially so they can be used as proxies to push onchain proposals to Nouns governance.
/// @notice For utmost security, Delegates never custody Nouns tokens and can only push proposals

contract Delegate {
    error NotWaveCore(address caller);

    address public immutable waveCore;

    constructor(address waveCore_) {
        waveCore = waveCore_;
    }

    function pushProposal(
        INounsDAOLogicV3 governor,
        NounsDAOV3Proposals.ProposalTxs calldata txs,
        string calldata description
    ) external returns (uint256 nounsProposalId) {
        if (msg.sender != waveCore) revert NotWaveCore(msg.sender);

        nounsProposalId =
            INounsDAOLogicV3(governor).propose(txs.targets, txs.values, txs.signatures, txs.calldatas, description);
    }
}
