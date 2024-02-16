// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
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
    error NonexistentIdeaId(uint256 ideaId);
    error AlreadyProposed(uint256 ideaId);
    error RoundIncomplete();
    error ClaimFailure();

    event IdeaCreated(IdeaInfo ideaInfo);
    event Sponsorship(address sponsor, uint96 ideaId, SponsorshipParams params);
    event IdeaProposed(IdeaInfo ideaInfo);

    /*
      Constants
    */

    /// @dev The length of time for a round in blocks, marking the block number where winning ideas are chosen 
    uint256 public constant roundLength = 1209600;
    /// @dev ERC1155 balance recordkeeping directly mirrors Ether values
    uint256 public constant minSponsorshipAmount = 0.001 ether;
    uint256 public constant decimals = 18;

    IPropLot private immutable __propLotCore;

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
    
    constructor(string memory uri_) ERC1155(uri_) {
        __propLotCore = IPropLot(msg.sender);
        
        ++currentRoundInfo.currentRound;
        ++_nextIdeaId;
    }

    function createIdea(NounsDAOV3Proposals.ProposalTxs memory ideaTxs, string memory description) public payable {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);

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

        emit IdeaCreated(ideaInfo);
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

    function finalizeRound() external {
        // check that roundLength has passed
        if (block.number - roundLength < currentRoundInfo.startBlock) revert RoundIncomplete();
        ++currentRoundInfo.currentRound;
        currentRoundInfo.startBlock = uint32(block.number);

        // identify number of proposals to push for current voting threshold
        (uint256 minRequiredVotes, uint256 numWinners) = __propLotCore.numEligibleProposerDelegates();
        
        // determine winners by checking balances
        uint96[] memory winningIds = new uint96[](numWinners);
        uint96 nextIdeaId = _nextIdeaId;
        //todo abstract to internal function & testing
        for (uint96 i = 1; i < nextIdeaId; ++i) {
            IdeaInfo storage currentIdeaInfo = ideaInfos[i];
            // skip previous winners
            if (currentIdeaInfo.isProposed) continue;

            for (uint256 j; j < numWinners; ++j) {
                IdeaInfo storage currentWinner = ideaInfos[winningIds[j]];
                if (currentIdeaInfo.totalFunding > currentWinner.totalFunding) {
                    for (uint256 k = numWinners - 1; k > j; k--) {
                        winningIds[k] = winningIds[k - 1];
                    }
                    winningIds[j] = i;
                    break;
                }
            }
        }

        // populate array with winning txs & description and aggregate total payout amount
        uint256 winningProposalsTotalFunding;
        IPropLot.Proposal[] memory winningProposals = new IPropLot.Proposal[](numWinners);
        for (uint256 l; l < numWinners; ++l) {
            IdeaInfo storage winner = ideaInfos[winningIds[l]];
            winner.isProposed = true;
            winningProposalsTotalFunding += winner.totalFunding;
            winningProposals[l] = winner.proposal;
        }

        IPropLot.Delegation[] memory delegations = __propLotCore.pushProposals(winningProposals);
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

    //todo override transfer & burn functions to make soulbound
}