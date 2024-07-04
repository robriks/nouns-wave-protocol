// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {ProposalValidatorLib} from "src/lib/ProposalValidatorLib.sol";

/// @title Wave Protocol Delegate
/// @author 📯📯📯.eth
/// @notice All Wave Protocol Delegate contracts are managed by the Wave Core. They are designed to receive
/// Nouns token delegation non-custodially so they can be used as proxies to push onchain proposals to Nouns governance.
/// @notice For utmost security, Delegates never custody Nouns tokens and can only push proposals

contract Delegate {
    using ProposalValidatorLib for ProposalTxs;

    error NotWaveCore(address caller);

    address public immutable waveCore;

    constructor(address waveCore_) {
        waveCore = waveCore_;
    }

    modifier onlyWaveCore {
        if (msg.sender != waveCore) revert NotWaveCore(msg.sender);
        _;
    }

    /// @dev Pushes a proposal to the Nouns governor, kickstarting the Nouns proposal process
    /// @notice May only be invoked by the Wave core contract as a part of the `IdeaTokenHub::finalizeWave()` flow
    function pushProposal(
        INounsDAOLogicV3 governor,
        ProposalTxs calldata txs,
        string calldata description
    ) external onlyWaveCore returns (uint256 nounsProposalId) {
        nounsProposalId =
            INounsDAOLogicV3(governor).propose(txs.targets, txs.values, txs.signatures, txs.calldatas, description);
    }

    /// @dev Updates an existing proposal which was made by this contract
    /// @notice May only be invoked through the Wave core contract, given a `proposalId` that is currently updatable 
    /// TODO: FIX STACK TOO DEEP CALLDATA PARAMS
    function updateProposal(
        INounsDAOLogicV3 governor, 
        uint256 nounsProposalId,
        ProposalTxs calldata updatedTxs, 
        string calldata updatedDescription, 
        string calldata updateMessage
    ) external onlyWaveCore {
        updatedTxs._validateProposalArity();

        // switch case to delineate calls to the granular functions offered by NounsDAOProposals.sol
        if (keccak256(bytes(updatedDescription)) == keccak256("")) {
            // if `updatedDescription` is empty, validate and update proposal transactions only
            ProposalValidatorLib._validateProposalTargetsAndOperations(updatedTxs, governor);
            governor.updateProposalTransactions(
                nounsProposalId, 
                updatedTxs.targets, 
                updatedTxs.values, 
                updatedTxs.signatures, 
                updatedTxs.calldatas, 
                updateMessage
            );
        } else if (updatedTxs.targets.length == 0) {
            // if `updatedTxs.targets` is empty, update description only
            governor.updateProposalDescription(nounsProposalId, updatedDescription, updateMessage);
        } else {
            // update both the proposal's transactions and description
            ProposalValidatorLib._validateProposalTargetsAndOperations(updatedTxs, governor);
            governor.updateProposal(nounsProposalId, updatedTxs.targets, updatedTxs.values, updatedTxs.signatures, updatedTxs.calldatas, updatedDescription, updateMessage);
        }
    }
}
