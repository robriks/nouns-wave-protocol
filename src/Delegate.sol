// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";

/// @title PropLot Protocol Delegate
/// @author 📯📯📯.eth
/// @notice All PropLot Protocol Delegate contracts are managed by the PropLot Core. They are designed to receive
/// Nouns token delegation non-custodially so they can be used as proxies to push onchain proposals to Nouns governance.
/// @notice For utmost security, Delegates never custody Nouns tokens and can only push proposals

contract Delegate {
    error NotPropLotCore(address caller);

    address public immutable propLot;

    constructor(address propLot_) {
        propLot = propLot_;
    }

    function pushProposal(
        INounsDAOLogicV3 governor,
        NounsDAOV3Proposals.ProposalTxs calldata txs,
        string calldata description
    ) external returns (uint256 nounsProposalId) {
        if (msg.sender != propLot) revert NotPropLotCore(msg.sender);

        nounsProposalId =
            INounsDAOLogicV3(governor).propose(txs.targets, txs.values, txs.signatures, txs.calldatas, description);
    }
}
