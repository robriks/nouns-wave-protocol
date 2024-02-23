// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {IPropLot} from "./interfaces/IPropLot.sol";
import {PropLot} from "./PropLot.sol";
import {console2} from "forge-std/console2.sol"; //todo delete

/// @title PropLot Protocol IdeaTokenHub
/// @author 📯📯📯.eth
/// @notice The PropLot Protocol ERC1155 token hub of ideas for Nouns governance proposal 

// This democratizes access to publicizing ideas for Nouns governance to any address by lending proposal power 
// and lowering the barrier of entry to submitting onchain proposals. Competition is introduced by an auction
// of ERC1155s, each `tokenId` representing a single proposal. 



// proposals -> 1155s that non-nounders can mint for a fee in support of (provenance + liquidity)
// 1155 w/ most mints wins onchain, two week proposal 'ritual' to push ideas onchain based on highest mints
// split sum of minting fees between existing noun delegates in a claim() func
// non-winning tokens w/ existing votes can roll over into following two week periods

contract IdeaTokenHub is ERC1155 {

    /*
      Structs
    */

    struct RoundInfo {
        uint32 currentRound;
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
    error RoundIncomplete();
    error ClaimFailure();

    event IdeaCreated(IPropLot.Proposal idea, address creator, uint96 ideaId, SponsorshipParams params);
    event Sponsorship(address sponsor, uint96 ideaId, SponsorshipParams params);
    event IdeaProposed(IdeaInfo ideaInfo);

    /*
      Constants
    */

    /// @dev ERC1155 balance recordkeeping directly mirrors Ether values
    uint256 public constant minSponsorshipAmount = 0.001 ether;
    uint256 public constant decimals = 18;
    /// @dev The length of time for a round in blocks, marking the block number where winning ideas are chosen 
    uint256 public immutable roundLength = 1209600;//todo change

    IPropLot private immutable __propLotCore;
    INounsDAOLogicV3 private immutable __nounsGovernor;

    /*
      Storage
    */

    RoundInfo public currentRoundInfo;
    uint96 private _nextIdeaId;

    /// @notice `type(uint96).max` size provides a large buffer for tokenIds, overflow is unrealistic
    mapping (uint96 => IdeaInfo) internal ideaInfos;
    mapping (address => mapping (uint96 => SponsorshipParams)) internal sponsorships;
    mapping (address => uint256) internal claimableYield;

    /*
      IdeaTokenHub
    */
    
    constructor(INounsDAOLogicV3 nounsGovernor_, string memory uri_) ERC1155(uri_) {
        __propLotCore = IPropLot(msg.sender);
        __nounsGovernor = nounsGovernor_;
        
        ++currentRoundInfo.currentRound;
        currentRoundInfo.startBlock = uint32(block.number);
        ++_nextIdeaId;
    }

    function createIdea(NounsDAOV3Proposals.ProposalTxs calldata ideaTxs, string calldata description) public payable {
        _validateIdeaCreation(ideaTxs, description);

        // cache in memory to save on SLOADs
        uint96 ideaId = _nextIdeaId;
        uint216 value = uint216(msg.value);
        IPropLot.Proposal memory proposal = IPropLot.Proposal(ideaTxs, description);
        IdeaInfo memory ideaInfo = IdeaInfo(value, uint32(block.number), false, proposal);
        ideaInfos[ideaId] = ideaInfo;
        ++_nextIdeaId;

        sponsorships[msg.sender][ideaId].contributedBalance = value;
        sponsorships[msg.sender][ideaId].isCreator = true;

        _mint(msg.sender, ideaId, msg.value, '');

        emit IdeaCreated(IPropLot.Proposal(ideaTxs, description), msg.sender, ideaId, SponsorshipParams(value, true));
    }

    function sponsorIdea(uint256 ideaId) public payable {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        // revert if a new round should be started
        if (block.number - roundLength >= currentRoundInfo.startBlock) revert RoundIncomplete();
        
        // typecast values can contain all Ether in existence && quintillions of ideas per human on earth
        uint216 value = uint216(msg.value);
        uint96 id = uint96(ideaId);
        if (ideaInfos[id].isProposed) revert AlreadyProposed(ideaId);

        ideaInfos[id].totalFunding += value;
        // `isCreator` for caller remains the same as at creation
        sponsorships[msg.sender][id].contributedBalance += value;

        SponsorshipParams storage params = sponsorships[msg.sender][id];
        
        _mint(msg.sender, ideaId, msg.value, '');

        emit Sponsorship(msg.sender, id, params);
    }

    function finalizeRound() external returns (IPropLot.Delegation[] memory delegations) {
        // check that roundLength has passed
        if (block.number - roundLength < currentRoundInfo.startBlock) revert RoundIncomplete();
        ++currentRoundInfo.currentRound;
        currentRoundInfo.startBlock = uint32(block.number);

        // identify number of proposals to push for current voting threshold
        (uint256 minRequiredVotes, uint256 numEligibleProposers) = __propLotCore.numEligibleProposerDelegates();
        console2.logString('numEligibleProposers:');
        console2.logUint(numEligibleProposers);

        // determine winners by obtaining list of ordered eligible ids
        uint96[] memory winningIds = getOrderedEligibleIdeaIds(numEligibleProposers);

        //todo move this assertion loop into an invariant test as it only asserts the invariant that `winningIds` is indeed ordered properly
        uint256 prevBal;
        for (uint256 z = winningIds.length; z > 0; --z) {
            uint256 index = z - 1;
            uint96 currentWinningId = winningIds[index];
            assert(ideaInfos[currentWinningId].totalFunding >= prevBal);

            prevBal = ideaInfos[currentWinningId].totalFunding;
        }

        // populate array with winning txs & description and aggregate total payout amount
        uint256 winningProposalsTotalFunding;
        IPropLot.Proposal[] memory winningProposals = new IPropLot.Proposal[](winningIds.length);
        for (uint256 l; l < winningIds.length; ++l) {
            uint96 currentWinnerId = winningIds[l];
            // if there are more eligible proposers than ideas, rightmost `winningIds` will be 0 which is an invalid `ideaId` value
            if (currentWinnerId == 0) break;

            IdeaInfo storage winner = ideaInfos[currentWinnerId];
            winner.isProposed = true;
            winningProposalsTotalFunding += winner.totalFunding;
            winningProposals[l] = winner.proposal;
        }

        delegations = __propLotCore.pushProposals(winningProposals);

        // calculate yield for returned valid delegations
        for (uint256 m; m < delegations.length; ++m) {
            uint256 denominator = 10_000 * minRequiredVotes / delegations[m].votingPower;
            uint256 yield = (winningProposalsTotalFunding / delegations.length) / denominator / 10_000;

            // todo remove in favor of invariant (as this should never happen)
            assert(yield != 0);
            
            // enable claiming of yield calculated as total revenue split between all delegations, proportional to delegated voting power
            address currentDelegator = delegations[m].delegator;
            claimableYield[currentDelegator] += yield;
        }
    }

    /// @dev Provides a way to collect the yield earned by Nounders who have delegated to PropLot for a full round
    /// @notice Reentrance prevented via CEI
    function claim() external {
        uint256 claimableAmt = claimableYield[msg.sender];
        claimableYield[msg.sender] = 0;
        (bool r,) = msg.sender.call{value: claimableAmt}('');
        if (!r) revert ClaimFailure();
    }

    /*
      Views
    */

    // todo: can this array eventually run into memory allocation issues (DOS) when enough `ideaIds` have been minted?
    /// @dev Fetches an array of `ideaIds` eligible for proposal, ordered by total funding
    /// @param optLimiter An optional limiter used to define the number of desired `ideaIds`, for example the number of 
    /// eligible proposers or winning ids. If provided, it will be used to define the length of the returned array
    /// @notice The returned array treats ineligible IDs (ie already proposed) as 0 values at the array end.
    /// Since 0 is an invalid `ideaId` value, these are simply filtered out when invoked within `finalizeRound()`
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

    //todo external function to return all previously proposed ideas

    function getIdeaInfo(uint256 ideaId) external view returns (IdeaInfo memory) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        return ideaInfos[uint96(ideaId)];
    }

    function getSponsorshipInfo(address sponsor, uint256 ideaId) public view returns (SponsorshipParams memory) {
        if (ideaId >= _nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        return sponsorships[sponsor][uint96(ideaId)];
    }

    function getclaimableYield(address nounder) external view returns (uint256) {
        return claimableYield[nounder];
    }
    
    function getNextIdeaId() public view returns (uint256) {
        return uint256(_nextIdeaId);
    }

    /*
      Internals
    */

    function _validateIdeaCreation(NounsDAOV3Proposals.ProposalTxs calldata _ideaTxs, string calldata _description) internal {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);
        
        // To account for Nouns governor contract upgradeability, `PROPOSAL_MAX_OPERATIONS` must be read dynamically
        uint256 maxOperations = __nounsGovernor.proposalMaxOperations();
        if (_ideaTxs.targets.length == 0 || _ideaTxs.targets.length > maxOperations) revert InvalidActionsCount(_ideaTxs.targets.length);
        
        if (
            _ideaTxs.targets.length != _ideaTxs.values.length ||
            _ideaTxs.targets.length != _ideaTxs.signatures.length ||
            _ideaTxs.targets.length != _ideaTxs.calldatas.length
        ) revert ProposalInfoArityMismatch();
        
        if (keccak256(bytes(_description)) == keccak256('')) revert InvalidDescription();
    }

    //todo override transfer & burn functions to make soulbound
}