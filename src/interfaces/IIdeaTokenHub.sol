// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {IPropLot} from "./IPropLot.sol";

/// @dev Interface for interacting with the PropLot IdeaTokenHub contract which manages tokenized ideas via ERC1155
interface IIdeaTokenHub {

    /*
      Structs
    */

    struct WaveInfo {
        uint32 currentWave;
        uint32 startBlock;
    }

    struct IdeaInfo {
        uint216 totalFunding;
        uint32 blockCreated;
        bool isProposed;
        IPropLot.Proposal proposal;
    }

    struct SponsorshipParams {
        uint216 contributedBalance;
        bool isCreator;
    }

    error BelowMinimumSponsorshipAmount(uint256 value);
    error InvalidActionsCount(uint256 count);
    error ProposalInfoArityMismatch();
    error InvalidDescription();
    error NonexistentIdeaId(uint256 ideaId);
    error AlreadyProposed(uint256 ideaId);
    error WaveIncomplete();
    error ClaimFailure();
    error Soulbound();

    event IdeaCreated(IPropLot.Proposal idea, address creator, uint96 ideaId, SponsorshipParams params);
    event Sponsorship(address sponsor, uint96 ideaId, SponsorshipParams params);
    event IdeaProposed(IdeaInfo ideaInfo);

    function minSponsorshipAmount() external view returns (uint256);
    function decimals() external view returns (uint256);
    function waveLength() external view returns (uint256);
    function currentWaveInfo() external view returns (uint32 currentWave, uint32 startBlock);
    
    /// @dev Creates a new ERC1155 token referred to by its token ID, ie its `ideaId` identifier
    /// @notice To combat spam and low-quality proposals, idea token creation requires a small minimum payment
    /// The Ether amount paid to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio
    function createIdea(NounsDAOV3Proposals.ProposalTxs calldata ideaTxs, string calldata description) external payable returns (uint96 newIdeaId);
    
    /// @dev Sponsors the existing ERC1155 tokenized idea specified by its ID. The Ether amount paid
    /// to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio
    /// @notice To incentivize smooth protocol transitions and continued rollover of auction waves,
    /// sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed
    function sponsorIdea(uint256 ideaId) external payable;

    /// @dev Finalizes a PropLot wave, marking the end of an auction wave. Winning ideas are selected by the highest 
    /// sponsored balances and officially proposed to the Nouns governance contracts. The number of winners varies
    /// depending on the available 'liquidity' of lent Nouns NFTs and their proposal power. Yield distributions are
    /// tallied by calling the PropLot Core and recording valid delegations in the `claimableYield` mapping where they
    /// can then be claimed at any time by a Nouns holder who has delegated to PropLot
    function finalizeWave() external returns (IPropLot.Delegation[] memory delegations, uint96[] memory winningIds, uint256[] memory nounsProposalIds);
    
    /// @dev Provides a way to collect the yield earned by Nounders who have delegated to PropLot for a full wave
    /// @notice Reentrance prevented via CEI
    function claim() external returns (uint256 claimAmt);

    /// @dev Fetches an array of `ideaIds` eligible for proposal, ordered by total funding
    /// @param optLimiter An optional limiter used to define the number of desired `ideaIds`, for example the number of 
    /// eligible proposers or winning ids. If provided, it will be used to define the length of the returned array
    function getOrderedEligibleIdeaIds(uint256 optLimiter) external view returns (uint96[] memory orderedEligibleIds);

    /// @dev Returns IDs of ideas which have already won waves and been proposed to Nouns governance
    /// @notice Intended for external use for improved devX
    function getOrderedProposedIdeaIds() external view returns (uint96[] memory orderedProposedIds);
    
    /// @dev Returns the IdeaInfo struct associated with a given `ideaId`
    function getIdeaInfo(uint256 ideaId) external view returns (IdeaInfo memory);

    /// @dev Returns the SponsorshipParams struct associated with a given `sponsor` address and `ideaId`
    function getSponsorshipInfo(address sponsor, uint256 ideaId) external view returns (SponsorshipParams memory);
    
    /// @dev Returns the funds available to claim for a Nounder who has delegated to PropLot
    function getClaimableYield(address nounder) external view returns (uint256);

    /// @dev Returns the next `ideaId` which makes use of the `tokenId` mechanic from the ERC1155 standard
    function getNextIdeaId() external view returns (uint256);
}
