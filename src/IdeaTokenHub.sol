// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC1155Upgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IIdeaTokenHub} from "./interfaces/IIdeaTokenHub.sol";
import {IPropLot} from "./interfaces/IPropLot.sol";
import {PropLot} from "./PropLot.sol";

/// @title PropLot Protocol IdeaTokenHub
/// @author 📯📯📯.eth
/// @notice The PropLot Protocol Idea Token Hub extends the Nouns governance ecosystem by tokenizing and crowdfunding ideas
/// for Nouns governance proposals. Nouns NFT holders earn yield in exchange for lending their tokens' proposal power to PropLot,
/// which democratizes access and lowers the barrier of entry for anyone with a worthy idea, represented as an ERC1155 tokenId.
/// Use of ERC1155 enables permissionless onchain minting with competition introduced by a crowdfunding auction.
/// Each `tokenId` represents a proposal idea which can be individually funded via permissionless mint. At the conclusion
/// of each auction, the winning tokenized ideas (with the most funding) are officially proposed into the Nouns governance system
/// via the use of lent Nouns proposal power, provided by token holders who have delegated to the protocol.

contract IdeaTokenHub is OwnableUpgradeable, UUPSUpgradeable, ERC1155Upgradeable, IIdeaTokenHub {
    /*
      Constants
    */

    uint256 public constant decimals = 18;

    /*
      Storage
    */

    IPropLot private __propLotCore;
    INounsDAOLogicV3 private __nounsGovernor;
    
    WaveInfo public currentWaveInfo;
    /// @dev ERC1155 balance recordkeeping directly mirrors Ether values
    uint256 public minSponsorshipAmount;
    /// @dev The length of time for a wave in blocks, marking the block number where winning ideas are chosen
    uint256 public waveLength;
    uint96 private _nextIdeaId;

    /// @notice `type(uint96).max` size provides a large buffer for tokenIds, overflow is unrealistic
    mapping(uint96 => IdeaInfo) internal ideaInfos;
    mapping(address => mapping(uint96 => SponsorshipParams)) internal sponsorships;
    mapping(address => uint256) internal claimableYield;

    /*
      IdeaTokenHub
    */

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address nounsGovernor_, uint256 minSponsorshipAmount_, uint256 waveLength_, string memory uri_) external virtual initializer {
        _transferOwnership(owner_);
        __ERC1155_init(uri_);

        __propLotCore = IPropLot(msg.sender);
        __nounsGovernor = INounsDAOLogicV3(nounsGovernor_);

        ++currentWaveInfo.currentWave;
        currentWaveInfo.startBlock = uint32(block.number);
        minSponsorshipAmount = minSponsorshipAmount_;
        waveLength = waveLength_;

        ++_nextIdeaId;
    }

    /// @inheritdoc IIdeaTokenHub
    function createIdea(NounsDAOV3Proposals.ProposalTxs calldata ideaTxs, string calldata description)
        public
        payable
        returns (uint96 newIdeaId)
    {
        // revert if a new wave should be started
        if (block.number - waveLength >= currentWaveInfo.startBlock) revert WaveIncomplete();
        
        _validateIdeaCreation(ideaTxs, description);

        // cache in memory to save on SLOADs
        newIdeaId = _nextIdeaId;
        uint216 value = uint216(msg.value);
        IdeaInfo memory ideaInfo = IdeaInfo(value, uint32(block.number), false, ideaTxs);
        ideaInfos[newIdeaId] = ideaInfo;
        ++_nextIdeaId;

        sponsorships[msg.sender][newIdeaId].contributedBalance = value;
        sponsorships[msg.sender][newIdeaId].isCreator = true;

        _mint(msg.sender, newIdeaId, msg.value, "");

        emit IdeaCreated(IPropLot.Proposal(ideaTxs, description), msg.sender, newIdeaId, SponsorshipParams(value, true));
    }

    /// @inheritdoc IIdeaTokenHub
    function sponsorIdea(uint256 ideaId) public payable {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        // revert if a new wave should be started
        if (block.number - waveLength >= currentWaveInfo.startBlock) revert WaveIncomplete();

        // typecast values can contain all Ether in existence && quintillions of ideas per human on earth
        uint216 value = uint216(msg.value);
        uint96 id = uint96(ideaId);
        if (ideaInfos[id].isProposed) revert AlreadyProposed(ideaId);

        ideaInfos[id].totalFunding += value;
        // `isCreator` for caller remains the same as at creation
        sponsorships[msg.sender][id].contributedBalance += value;

        SponsorshipParams storage params = sponsorships[msg.sender][id];

        _mint(msg.sender, ideaId, msg.value, "");

        emit Sponsorship(msg.sender, id, params);
    }

    /// @inheritdoc IIdeaTokenHub
    /// @notice To save gas on `description` string SSTOREs, descriptions are stored offchain and their winning IDs must be re-validated in memory
    function finalizeWave(uint96[] calldata offchainWinningIds, string[] calldata offchainDescriptions)
        external
        returns (
            IPropLot.Delegation[] memory delegations,
            uint256[] memory nounsProposalIds
        )
    {
        // check that waveLength has passed
        if (block.number - waveLength < currentWaveInfo.startBlock) revert WaveIncomplete();
        ++currentWaveInfo.currentWave;
        currentWaveInfo.startBlock = uint32(block.number);

        // determine winners from ordered list if there are any
        uint256 minRequiredVotes;
        uint256 numEligibleProposers;
        uint96[] memory winningIds;
        (minRequiredVotes, numEligibleProposers, winningIds) = getWinningIdeaIds();
        // terminate early when there is not enough liquidity for proposals to be made
        if (numEligibleProposers == 0) return (new IPropLot.Delegation[](0), new uint256[](0));

        // re-validate the provided offchain parameter lengths against returned canonical onchain state
        uint256 descriptionsLen = offchainDescriptions.length;
        if (
            numEligibleProposers < descriptionsLen 
            || winningIds.length != descriptionsLen 
            || winningIds.length != offchainWinningIds.length
        ) revert InvalidOffchainDataProvided();

        // populate array with winning txs & description and aggregate total payout amount
        uint256 winningProposalsTotalFunding;
        IPropLot.Proposal[] memory winningProposals = new IPropLot.Proposal[](winningIds.length);
        for (uint256 i; i < winningIds.length; ++i) {
            uint96 currentWinnerId = winningIds[i];
            // re-validate canonical winnerId values against provided ones
            if (offchainWinningIds[i] != currentWinnerId) revert InvalidOffchainDataProvided();

            IdeaInfo storage winner = ideaInfos[currentWinnerId];
            winner.isProposed = true;
            winningProposalsTotalFunding += winner.totalFunding;
            winningProposals[i] = IPropLot.Proposal(winner.proposalTxs, offchainDescriptions[i]);
        }

        (delegations, nounsProposalIds) = __propLotCore.pushProposals(winningProposals);

        // calculate yield for returned valid delegations
        for (uint256 j; j < delegations.length; ++j) {
            uint256 denominator = 10_000 * minRequiredVotes / delegations[j].votingPower;
            uint256 yield = (winningProposalsTotalFunding / delegations.length) / denominator / 10_000;

            // enable claiming of yield calculated as total revenue split between all delegations, proportional to delegated voting power
            address currentDelegator = delegations[j].delegator;
            claimableYield[currentDelegator] += yield;
        }
    }

    /// @inheritdoc IIdeaTokenHub
    function claim() external returns (uint256 claimAmt) {
        claimAmt = claimableYield[msg.sender];
        delete claimableYield[msg.sender];

        (bool r,) = msg.sender.call{value: claimAmt}("");
        if (!r) revert ClaimFailure();
    }

    /// @inheritdoc IIdeaTokenHub
    function setMinSponsorshipAmount(uint256 newMinSponsorshipAmount) external onlyOwner {
        minSponsorshipAmount = newMinSponsorshipAmount;
    }

    /// @inheritdoc IIdeaTokenHub
    function setWaveLength(uint256 newWavelength) external onlyOwner {
        waveLength = newWavelength;
    }

    /*
      Views
    */

    /// @inheritdoc IIdeaTokenHub
    /// @notice Intended for offchain usage to aid in fetching offchain `description` string data before calling `finalizeWave()`
    /// If a full list of eligible IdeaIds ordered by current funding is desired, use `getOrderedEligibleIdeaIds(0)` instead
    function getWinningIdeaIds() public view returns (uint256 minRequiredVotes, uint256 numEligibleProposers, uint96[] memory winningIds) {
        // identify number of proposals to push for current voting threshold
        (minRequiredVotes, numEligibleProposers) = __propLotCore.numEligibleProposerDelegates();
        // terminate early when there is not enough liquidity for proposals to be made; avoids issues with `getOrderedEligibleIdeaIds()`
        if (numEligibleProposers == 0) return (minRequiredVotes, 0, new uint96[](0));

        // determine winners from ordered list if there are any
        uint96[] memory unfilteredWinningIds = getOrderedEligibleIdeaIds(numEligibleProposers);

        uint256 actualLen = unfilteredWinningIds.length;
        // filter returned array accounting for case when `numEligibleProposers` is greater than eligible ideas
        for (uint256 i; i < actualLen; ++i) {
            // proposed or nonexistent `winningIds` on right end of array will be 0 which is an invalid `ideaId` value
            if (unfilteredWinningIds[i] == 0) {
                if (i == 0) {
                    actualLen = 0;
                    break;
                } else {
                    actualLen = i + 1;
                    break;
                }
            }
        }

        // populate final filtered array
        winningIds = new uint96[](actualLen);
        for (uint256 j; j < actualLen; ++j) {
            winningIds[j] = unfilteredWinningIds[j];
        }
    }
    
    /// @inheritdoc IIdeaTokenHub
    /// @notice The returned array treats ineligible IDs (ie already proposed) as 0 values at the array end.
    /// Since 0 is an invalid `ideaId`, these are filtered out when invoked by `finalizeWave()` and `getWinningIdeaIds()`
    function getOrderedEligibleIdeaIds(uint256 optLimiter) public view returns (uint96[] memory orderedEligibleIds) {
        // cache in memory to reduce SLOADs
        uint256 nextIdeaId = getNextIdeaId();
        uint256 len;
        if (optLimiter == 0 || optLimiter >= nextIdeaId) {
            // there cannot be more winners than existing `ideaIds`
            len = nextIdeaId - 1;
        } else {
            len = optLimiter;
        }

        orderedEligibleIds = new uint96[](len);
        for (uint96 i = 1; i < nextIdeaId; ++i) {
            IdeaInfo storage currentIdeaInfo = ideaInfos[i];
            // skip previous winners
            if (currentIdeaInfo.isProposed) {
                continue;
            }

            // compare `totalFunding` and push winners into array, ordering by highest funding
            for (uint256 j; j < len; ++j) {
                IdeaInfo storage currentWinner = ideaInfos[orderedEligibleIds[j]];
                // if a tokenId with higher funding is found, reorder array from right to left and then insert it
                if (currentIdeaInfo.totalFunding > currentWinner.totalFunding) {
                    for (uint256 k = len - 1; k > j; --k) {
                        orderedEligibleIds[k] = orderedEligibleIds[k - 1];
                    }

                    orderedEligibleIds[j] = i; // i represents top level loop's `ideaId`
                    break;
                }
            }
        }
    }

    /// @inheritdoc IIdeaTokenHub
    function getOrderedProposedIdeaIds() public view returns (uint96[] memory orderedProposedIds) {
        // cache in memory to reduce SLOADs
        uint256 nextIdeaId = getNextIdeaId();
        uint256 len;

        // get length of proposed ideas array
        for (uint96 i = 1; i < nextIdeaId; ++i) {
            IdeaInfo storage currentIdeaInfo = ideaInfos[i];
            // skip previous winners
            if (currentIdeaInfo.isProposed) {
                len++;
            }
        }

        // populate array
        uint256 index;
        orderedProposedIds = new uint96[](len);
        for (uint96 j = 1; j < nextIdeaId; ++j) {
            IdeaInfo storage currentIdeaInfo = ideaInfos[j];
            if (currentIdeaInfo.isProposed) {
                orderedProposedIds[index] = j;
                index++;
            }
        }
    }

    function getIdeaInfo(uint256 ideaId) external view returns (IdeaInfo memory) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        return ideaInfos[uint96(ideaId)];
    }

    function getSponsorshipInfo(address sponsor, uint256 ideaId) public view returns (SponsorshipParams memory) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        return sponsorships[sponsor][uint96(ideaId)];
    }

    function getClaimableYield(address nounder) external view returns (uint256) {
        return claimableYield[nounder];
    }

    function getOptimisticYieldEstimate(address nounder) external view returns (uint256 yieldEstimate) {
        // get ordered list of winningIdeas, truncated by numEligibleProposers
        (,, uint96[] memory winningIds) = getWinningIdeaIds();
        uint216 expectedTotalYield;
        for (uint256 i; i < winningIds.length; ++i) {
            expectedTotalYield += ideaInfos[winningIds[i]].totalFunding;
        }

        // cycle through optimistic delegations for total optimistic voting power to estimate yield
        IPropLot.Delegation[] memory optimisticDelegations = __propLotCore.getOptimisticDelegations();
        uint16 totalDelegatedVotes;
        uint256 nounderVotingPower;
        for (uint256 j; j < optimisticDelegations.length; ++j) {
            IPropLot.Delegation memory currentDelegation = optimisticDelegations[j];
            totalDelegatedVotes += currentDelegation.votingPower;

            // identify match if it exists and save relevant `votingPower`
            if (currentDelegation.delegator == nounder) nounderVotingPower = currentDelegation.votingPower;
        }

        yieldEstimate = expectedTotalYield / totalDelegatedVotes * nounderVotingPower;
    }

    function getNextIdeaId() public view returns (uint256) {
        return uint256(_nextIdeaId);
    }

    /*
      Internals
    */

    function _validateIdeaCreation(NounsDAOV3Proposals.ProposalTxs calldata _ideaTxs, string calldata _description)
        internal
    {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);

        // To account for Nouns governor contract upgradeability, `PROPOSAL_MAX_OPERATIONS` must be read dynamically
        uint256 maxOperations = __nounsGovernor.proposalMaxOperations();
        if (_ideaTxs.targets.length == 0 || _ideaTxs.targets.length > maxOperations) {
            revert InvalidActionsCount(_ideaTxs.targets.length);
        }

        if (
            _ideaTxs.targets.length != _ideaTxs.values.length || _ideaTxs.targets.length != _ideaTxs.signatures.length
                || _ideaTxs.targets.length != _ideaTxs.calldatas.length
        ) revert ProposalInfoArityMismatch();

        if (keccak256(bytes(_description)) == keccak256("")) revert InvalidDescription();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        if (from != address(0x0) && to != address(0x0)) revert Soulbound();
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _authorizeUpgrade(address /*newImplementation*/) internal virtual override {
        if (msg.sender != owner()) revert IPropLot.Unauthorized();
    }
}
