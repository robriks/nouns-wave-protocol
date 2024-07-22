// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
import {INounsDAOLogicV4} from "src/interfaces/INounsDAOLogicV4.sol";

/// @title Proposal Validator Library
/// @author 📯📯📯.eth
/// @dev This library provides modular proposal validation logic inherited by Wave Protocol's
/// IdeaTokenHub and Delegate contracts, used to validate proposals when created or updated

library ProposalValidatorLib {
    error ProposalInfoArityMismatch();
    error InvalidDescription();
    error InvalidActionsCount(uint256 exceedsMaxOperations);

    /// @notice To account for Nouns governor contract upgradeability, `PROPOSAL_MAX_OPERATIONS` must be read dynamically
    function _validateProposalTargetsAndOperations(ProposalTxs memory txs, INounsDAOLogicV4 governor) internal pure {
        uint256 maxOperations = governor.proposalMaxOperations();
        if (txs.targets.length == 0 || txs.targets.length > maxOperations) {
            revert InvalidActionsCount(txs.targets.length);
        }
    }

    function _validateProposalArity(ProposalTxs memory txs) internal pure {
        if (
            txs.targets.length != txs.values.length || txs.targets.length != txs.signatures.length
                || txs.targets.length != txs.calldatas.length
        ) revert ProposalInfoArityMismatch();
    }
}