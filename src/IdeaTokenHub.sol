// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {OwnableUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC1155Upgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IIdeaTokenHub} from "./interfaces/IIdeaTokenHub.sol";
import {IWave} from "./interfaces/IWave.sol";
import {IRenderer} from "./SVG/IRenderer.sol";

/// @title Wave Protocol IdeaTokenHub
/// @author 📯📯📯.eth
/// @notice The Wave Protocol Idea Token Hub extends the Nouns governance ecosystem by tokenizing and crowdfunding ideas
/// for Nouns governance proposals. Nouns NFT holders earn yield in exchange for lending their tokens' proposal power to Wave,
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

    IWave private __waveCore;
    INounsDAOLogicV3 private __nounsGovernor;
    IRenderer private __renderer;

    /// @dev ERC1155 balance recordkeeping directly mirrors Ether values
    uint256 public minSponsorshipAmount;
    /// @dev The length of time for a wave in blocks, marking the block number where winning ideas are chosen
    uint256 public waveLength;
    uint96 private _currentWaveId;
    uint96 private _nextIdeaId;

    /// @notice `type(uint96).max` size provides a large buffer for tokenIds, overflow is unrealistic
    mapping(uint96 => IdeaInfo) internal ideaInfos;
    mapping(uint96 => WaveInfo) internal waveInfos;
    mapping(address => mapping(uint96 => SponsorshipParams)) internal sponsorships;
    mapping(address => uint256) internal claimableYield;

    /*
      IdeaTokenHub
    */

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address nounsGovernor_,
        uint256 minSponsorshipAmount_,
        uint256 waveLength_,
        address renderer_,
        string memory uri_
    ) external virtual initializer {
        _transferOwnership(owner_);
        __ERC1155_init(uri_);

        __waveCore = IWave(msg.sender);
        __nounsGovernor = INounsDAOLogicV3(nounsGovernor_);
        _setRenderer(renderer_);

        waveInfos[_currentWaveId].startBlock = uint32(block.number);
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
        if (block.number - waveLength >= waveInfos[_currentWaveId].startBlock) revert WaveIncomplete();

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

        emit IdeaCreated(IWave.Proposal(ideaTxs, description), msg.sender, newIdeaId, SponsorshipParams(value, true));
    }

    /// @inheritdoc IIdeaTokenHub
    function sponsorIdea(uint96 ideaId) public payable {
        _sponsorIdea(ideaId);
        SponsorshipParams storage params = sponsorships[msg.sender][ideaId];

        emit Sponsorship(msg.sender, ideaId, params, "");
    }

    /// @inheritdoc IIdeaTokenHub
    function sponsorIdeaWithReason(uint96 ideaId, string calldata reason) public payable {
        _sponsorIdea(ideaId);
        SponsorshipParams storage params = sponsorships[msg.sender][ideaId];

        emit Sponsorship(msg.sender, ideaId, params, reason);
    }

    /// @inheritdoc IIdeaTokenHub
    /// @notice To save gas on `description` string SSTOREs, descriptions are stored offchain and their winning IDs must be re-validated in memory
    function finalizeWave(uint96[] calldata offchainWinningIds, string[] calldata offchainDescriptions)
        external
        returns (IWave.Delegation[] memory delegations, uint256[] memory nounsProposalIds)
    {
        // transition contract state to next Wave
        uint96 previousWaveId = _updateWaveState();

        // determine winners from ordered list if there are any
        uint256 minRequiredVotes;
        uint256 numEligibleProposers;
        uint96[] memory winningIds;
        (minRequiredVotes, numEligibleProposers, winningIds) = getWinningIdeaIds();
        // terminate early when there is not enough liquidity for proposals to be made
        if (numEligibleProposers == 0) return (new IWave.Delegation[](0), new uint256[](0));

        // re-validate the provided offchain parameter lengths against returned canonical onchain state
        uint256 descriptionsLen = offchainDescriptions.length;
        if (
            numEligibleProposers < descriptionsLen || winningIds.length != descriptionsLen
                || winningIds.length != offchainWinningIds.length
        ) revert InvalidOffchainDataProvided();

        // validate + populate winning ideaId arrays, update `ideaInfos` mapping, and aggregate total yield payout
        (
            uint256 winningProposalsTotalFunding,
            IWave.Proposal[] memory winningProposals,
            ProposalInfo[] memory proposedIdeas
        ) = _processWinningIdeas(offchainWinningIds, offchainDescriptions, winningIds);

        (delegations, nounsProposalIds) = __waveCore.pushProposals(winningProposals);

        // populate array's `nounsProposalId` struct field for event emission now that they are known
        for (uint256 i; i < proposedIdeas.length; ++i) {
            proposedIdeas[i].nounsProposalId = nounsProposalIds[i];
        }

        emit WaveFinalized(proposedIdeas, waveInfos[previousWaveId]);

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
    function getWinningIdeaIds()
        public
        view
        returns (uint256 minRequiredVotes, uint256 numEligibleProposers, uint96[] memory winningIds)
    {
        // identify number of proposals to push for current voting threshold
        (minRequiredVotes, numEligibleProposers) = __waveCore.numEligibleProposerDelegates();
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
                    actualLen = i;
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

    /// @inheritdoc IIdeaTokenHub
    function getIdeaInfo(uint256 ideaId) external view returns (IdeaInfo memory) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        return ideaInfos[uint96(ideaId)];
    }

    /// @inheritdoc IIdeaTokenHub
    function getParentWaveId(uint256 ideaId) external view returns (uint256 waveId) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);

        // binary search for parent Wave
        uint96 left;
        uint96 right = _currentWaveId;
        uint32 blockCreated = ideaInfos[uint96(ideaId)].blockCreated;
        while (left <= right) {
            uint96 middle = left + (right - left) / 2;
            WaveInfo storage currentWave = waveInfos[middle];

            // catch case where `ideaId` was created in the same block as Wave finalization
            if (currentWave.startBlock <= blockCreated && blockCreated <= currentWave.endBlock) {
                return middle;
            } else if (blockCreated < currentWave.startBlock) {
                if (middle == 0) break; // prevent underflow
                right = middle - 1;
            } else {
                left = middle + 1;
            }
        }
    }

    /// @inheritdoc IIdeaTokenHub
    function getSponsorshipInfo(address sponsor, uint256 ideaId) public view returns (SponsorshipParams memory) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        return sponsorships[sponsor][uint96(ideaId)];
    }

    /// @inheritdoc IIdeaTokenHub
    function getClaimableYield(address nounder) external view returns (uint256) {
        return claimableYield[nounder];
    }

    /// @inheritdoc IIdeaTokenHub
    function getOptimisticYieldEstimate(address nounder) external view returns (uint256 yieldEstimate) {
        // get ordered list of winningIdeas, truncated by numEligibleProposers
        (,, uint96[] memory winningIds) = getWinningIdeaIds();
        uint216 expectedTotalYield;
        for (uint256 i; i < winningIds.length; ++i) {
            expectedTotalYield += ideaInfos[winningIds[i]].totalFunding;
        }

        // cycle through optimistic delegations for total optimistic voting power to estimate yield
        IWave.Delegation[] memory optimisticDelegations = __waveCore.getOptimisticDelegations();
        uint16 totalDelegatedVotes;
        uint256 nounderVotingPower;
        for (uint256 j; j < optimisticDelegations.length; ++j) {
            IWave.Delegation memory currentDelegation = optimisticDelegations[j];
            totalDelegatedVotes += currentDelegation.votingPower;

            // identify match if it exists and save relevant `votingPower`
            if (currentDelegation.delegator == nounder) nounderVotingPower = currentDelegation.votingPower;
        }

        yieldEstimate = expectedTotalYield / totalDelegatedVotes * nounderVotingPower;
    }

    /// @inheritdoc IIdeaTokenHub
    function getWaveInfo(uint96 waveId) public view returns (WaveInfo memory) {
        return waveInfos[waveId];
    }

    /// @inheritdoc IIdeaTokenHub
    function getCurrentWaveInfo() external view returns (uint96 currentWaveId, WaveInfo memory currentWaveInfo) {
        currentWaveId = _currentWaveId;
        currentWaveInfo = getWaveInfo(currentWaveId);
    }

    /// @inheritdoc IIdeaTokenHub
    function getNextIdeaId() public view returns (uint256) {
        return uint256(_nextIdeaId);
    }

    /*
      Metadata URI 
    */
    
    /// @dev Returns dynamically generated SVG metadata, rendered according to onchain state
    function uri(uint256 ideaTokenId) public view virtual override returns (string memory) {
        return __renderer.generateSVG(ideaTokenId);
    }

    /// @inheritdoc IIdeaTokenHub
    function setRenderer(address newRenderer) external onlyOwner {
        _setRenderer(newRenderer);
    }

    /// @inheritdoc IIdeaTokenHub
    function setStaticURI(string memory newURI) external onlyOwner {
        _setURI(newURI);
    }

    /*
      Internals
    */

    function _setRenderer(address newRenderer) internal {
        __renderer = IRenderer(newRenderer);
    }

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

    function _sponsorIdea(uint96 _ideaId) internal {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);
        if (_ideaId >= _nextIdeaId || _ideaId == 0) revert NonexistentIdeaId(_ideaId);
        // revert if a new wave should be started
        if (block.number - waveLength >= waveInfos[_currentWaveId].startBlock) revert WaveIncomplete();

        // typecast values can contain all Ether in existence && quintillions of ideas per human on earth
        uint216 value = uint216(msg.value);
        if (ideaInfos[_ideaId].isProposed) revert AlreadyProposed(_ideaId);

        ideaInfos[_ideaId].totalFunding += value;
        // `isCreator` for caller remains the same as at creation
        sponsorships[msg.sender][_ideaId].contributedBalance += value;

        _mint(msg.sender, _ideaId, msg.value, "");
    }

    function _updateWaveState() internal returns (uint96 previousWaveId) {
        // cache & advance waveId using post-increment
        previousWaveId = _currentWaveId++;
        WaveInfo storage previousWaveInfo = waveInfos[previousWaveId];

        // check that waveLength has passed
        if (block.number - waveLength < previousWaveInfo.startBlock) revert WaveIncomplete();

        // both `endBlock` of previous Wave and `startBlock` of current Wave are updated for better offchain readability
        uint32 currentBlock = uint32(block.number);
        previousWaveInfo.endBlock = currentBlock;
        uint96 currentWaveId = previousWaveId + 1;
        waveInfos[currentWaveId].startBlock = currentBlock;
    }

    function _processWinningIdeas(
        uint96[] calldata _offchainWinningIds,
        string[] calldata _offchainDescriptions,
        uint96[] memory _winningIds
    )
        internal
        returns (
            uint256 winningProposalsTotalFunding,
            IWave.Proposal[] memory winningProposals,
            ProposalInfo[] memory proposedIdeas
        )
    {
        // populate array with winning txs & description and aggregate total payout amount
        uint256 len = _winningIds.length;
        winningProposals = new IWave.Proposal[](len);
        proposedIdeas = new ProposalInfo[](len);
        for (uint256 i; i < len; ++i) {
            uint96 currentWinnerId = _winningIds[i];
            // re-validate canonical winnerId values against provided ones
            if (_offchainWinningIds[i] != currentWinnerId) revert InvalidOffchainDataProvided();

            IdeaInfo storage winner = ideaInfos[currentWinnerId];
            winner.isProposed = true;
            winningProposalsTotalFunding += winner.totalFunding;
            winningProposals[i] = IWave.Proposal(winner.proposalTxs, _offchainDescriptions[i]);

            // use placeholder value since `nounsProposalId` is not known and will be assigned by Nouns Governor
            proposedIdeas[i] = ProposalInfo(0, uint256(currentWinnerId), winner.totalFunding, winner.blockCreated);
        }
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

    function _authorizeUpgrade(address /*newImplementation*/ ) internal virtual override {
        if (msg.sender != owner()) revert IWave.Unauthorized();
    }
}
