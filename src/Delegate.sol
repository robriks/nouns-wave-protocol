// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
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
    function updateProposal(
        INounsDAOLogicV3 governor, 
        uint256 nounsProposalId,
        ProposalTxs calldata updatedTxs, 
        string calldata updatedDescription, 
        string calldata updateMessage
    ) external onlyWaveCore {
        _validateProposalArity(updatedTxs);

        // switch case to delineate calls to the granular functions offered by NounsDAOProposals.sol

        // if `updatedDescription` is empty:
        if (keccak256(bytes(updatedDescription)) == keccak256("")) {
            governor.updateProposalTransactions(
                nounsProposalId, 
                updatedTxs.targets, 
                updatedTxs.values, 
                updatedTxs.signatures, 
                updatedTxs.calldatas, 
                updateMessage
            );
        } else if () // if `updatedTxs.targets.length == 0` _validateProposalTargetsAndOperations() and updateDescription only
        
        governor.updateProposalDescription(proposalId, description, updateMessage);

        // else () `updatedTxs.targets.length != 0 && updatedDescription != ""` so update both
        governor.updateProposal(proposalId, targets, values, signatures, calldatas, description, updateMessage);
    }

    // todo: move internal validation functiosn and IdeaTokenHub::_validateIdeaCreation into separate ProposalValidator library
    function _validateProposalTargetsAndOperations(ProposalTxs calldata txs) internal pure {
        // To account for Nouns governor contract upgradeability, `PROPOSAL_MAX_OPERATIONS` must be read dynamically
        uint256 maxOperations = __nounsGovernor.proposalMaxOperations();
        if (_ideaTxs.targets.length == 0 || _ideaTxs.targets.length > maxOperations) {
            revert InvalidActionsCount(_ideaTxs.targets.length);
        }
    }

    // todo: move into library 
    function _validateProposalArity(ProposalTxs calldata txs) internal pure {
        if (
            _ideaTxs.targets.length != _ideaTxs.values.length || _ideaTxs.targets.length != _ideaTxs.signatures.length
                || _ideaTxs.targets.length != _ideaTxs.calldatas.length
        ) revert ProposalInfoArityMismatch();
    }
}
