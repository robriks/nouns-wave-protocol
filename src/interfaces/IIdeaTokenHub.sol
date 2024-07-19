// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ProposalTxs} from "src/interfaces/ProposalTxs.sol";
import {IWave} from "./IWave.sol";

/// @dev Interface for interacting with the Wave IdeaTokenHub contract which manages tokenized ideas via ERC1155
interface IIdeaTokenHub {
    /*
      Structs
    */

    struct WaveInfo {
        uint32 startBlock;
        uint32 endBlock;
    }

    struct IdeaInfo {
        uint216 totalFunding;
        uint32 blockCreated;
        bool isProposed;
        ProposalTxs proposalTxs;
    }

    struct SponsorshipParams {
        uint216 contributedBalance;
        bool isCreator;
    }

    struct ProposalInfo {
        uint256 nounsProposalId;
        uint256 waveIdeaId;
        uint216 totalFunding;
        uint32 blockCreated;
    }

    error BelowMinimumSponsorshipAmount(uint256 value);
    error InvalidOffchainDataProvided();
    error NonexistentIdeaId(uint256 ideaId);
    error AlreadyProposed(uint256 ideaId);
    error WaveIncomplete();
    error ClaimFailure();
    error Soulbound();

    event IdeaCreated(IWave.Proposal idea, address creator, uint96 ideaId, SponsorshipParams params);
    event Sponsorship(address sponsor, uint96 ideaId, SponsorshipParams params, string reason);
    event WaveFinalized(ProposalInfo[] proposedIdeas, WaveInfo previousWaveInfo);

    function minSponsorshipAmount() external view returns (uint256);
    function decimals() external view returns (uint256);
    function waveLength() external view returns (uint256);

    function initialize(
        address owner_,
        address nounsGovernor_,
        uint256 minSponsorshipAmount_,
        uint256 waveLength_,
        address renderer_,
        string memory uri_
    ) external;

    /// @dev Creates a new ERC1155 token referred to by its token ID, ie its `ideaId` identifier
    /// @notice To combat spam and low-quality proposals, idea token creation requires a small minimum payment
    /// The Ether amount paid to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio
    function createIdea(ProposalTxs calldata ideaTxs, string calldata description)
        external
        payable
        returns (uint96 newIdeaId);

    /// @dev Sponsors the existing ERC1155 tokenized idea specified by its ID. The Ether amount paid
    /// to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio
    /// @notice To incentivize smooth protocol transitions and continued rollover of auction waves,
    /// sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed
    function sponsorIdea(uint96 ideaId) external payable;

    /// @dev Idential execution to `sponsorIdea()` emitting a separate event with additional description string
    /// @notice To incentivize smooth protocol transitions and continued rollover of auction waves,
    /// sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed
    function sponsorIdeaWithReason(uint96 ideaId, string calldata reason) external payable;

    /// @dev Finalizes a Wave wave, marking the end of an auction wave. Winning ideas are selected by the highest
    /// sponsored balances and officially proposed to the Nouns governance contracts. The number of winners varies
    /// depending on the available 'liquidity' of lent Nouns NFTs and their proposal power. Yield distributions are
    /// tallied by calling the Wave Core and recording valid delegations in the `claimableYield` mapping where they
    /// can then be claimed at any time by a Nouns holder who has delegated to Wave
    function finalizeWave(uint96[] calldata offchainWinningIds, string[] calldata offchainDescriptions)
        external
        returns (IWave.Delegation[] memory delegations, uint256[] memory nounsProposalIds);

    /// @dev Provides a way to collect the yield earned by Nounders who have delegated to Wave for a full wave
    /// @notice Reentrance prevented via CEI
    function claim() external returns (uint256 claimAmt);

    /// @dev Returns an array of the current wave's leading IdeaIds where the array length is determined
    /// by the protocol's number of available proposer delegates, fetched from the WaveCore contract
    function getWinningIdeaIds()
        external
        view
        returns (uint256 minRequiredVotes, uint256 numEligibleProposers, uint96[] memory winningIds);

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

    /// @dev Returns the funds available to claim for a Nounder who has delegated to Wave
    function getClaimableYield(address nounder) external view returns (uint256);

    /// @dev Returns an estimate of expected yield for the given Nounder LP who has delegated voting power to Wave
    /// @notice Returned estimate is based on optimistic state and is subject to change until Wave finalization
    function getOptimisticYieldEstimate(address nounder) external view returns (uint256 yieldEstimate);

    /// @dev Returns information pertaining to the given Wave ID as a `WaveInfo` struct
    function getWaveInfo(uint96 waveId) external view returns (WaveInfo memory);

    /// @dev Returns information pertaining to the current Wave as a `WaveInfo` struct
    function getCurrentWaveInfo() external view returns (uint96 currentWaveId, WaveInfo memory currentWaveInfo);

    /// @dev Returns the `waveId` representing the parent Wave during which the given `ideaId` was created
    function getParentWaveId(uint256 ideaId) external view returns (uint256 waveId);

    /// @dev Returns the next `ideaId` which makes use of the `tokenId` mechanic from the ERC1155 standard
    function getNextIdeaId() external view returns (uint256);

    /*
      Access-Controlled Functions
    */

    /// @dev Sets a new Renderer contract to dynamically render SVG metadata onchain
    /// @notice Only callable by the owner
    function setRenderer(address newRenderer) external;

    /// @dev Sets the traditional static string-based URI which is not used
    /// but is included for backwards compatibility
    /// @notice Only callable by the owner
    function setStaticURI(string memory newURI) external;

    /// @dev Sets the new minimum funding required to create and sponsor tokenized ideas
    /// @notice Only callable by the owner
    function setMinSponsorshipAmount(uint256 newMinSponsorshipAmount) external;

    /// @dev Sets the new length of Wave waves in blocks
    /// @notice Only callable by the owner
    function setWaveLength(uint256 newWavelength) external;
}