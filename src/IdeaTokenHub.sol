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

    // struct Sponsorship {
    //     address sponsor;
    //     uint96 ideaId;
    //     SponsorshipParams params;
    // }

    struct SponsorshipParams {
        uint216 contributedBalance;
        bool isCreator;
    }

    struct IdeaRecord {
        uint216 totalFunding;
        uint32 blockCreated;
        bool isProposed;
        NounsDAOV3Proposals.ProposalTxs ideaTxs;
        string description;
    }

    struct RoundInfo {
        uint32 currentRound;
        uint32 startBlock;
    }

    error BelowMinimumSponsorshipAmount(uint256 value);
    error NonexistentIdeaId(uint256 ideaId);
    error AlreadyProposed(uint256 ideaId);
    error RoundIncomplete();

    event IdeaCreated(IdeaRecord ideaRecord);
    event Sponsorship(address sponsor, uint96 ideaId, SponsorshipParams params);
    event IdeaProposed(IdeaRecord ideaRecord);

    /*
      Constants
    */

    /// @dev The length of time for a round in blocks, marking the block number where winning ideas are chosen 
    uint256 public constant roundLength = 1209600;
    /// @dev ERC1155 balance recordkeeping directly mirrors Ether values
    uint256 public constant minSponsorshipAmount = 0.001 ether;
    uint256 public constant decimals = 18;

    IPropLot private immutable propLotCore;

    /*
      Storage
    */

    RoundInfo public currentRoundInfo;
    uint256 nextIdeaId;

    /// @notice `type(uint96).max` size provides a large buffer for tokenIds, overflow is unrealistic
    mapping (uint96 => IdeaRecord) internal ideaRecords;
    mapping (address => mapping (uint96 => SponsorshipParams)) internal sponsorships;

    constructor(string memory uri_) ERC1155(uri_) {
        propLotCore = IPropLot(msg.sender);
        
        ++currentRoundInfo.currentRound;
        ++nextIdeaId;
    }

    function createIdea(NounsDAOV3Proposals.ProposalTxs memory ideaTxs, string memory description) public payable {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);

        uint96 ideaId = uint96(nextIdeaId);
        uint216 value = uint216(msg.value);
        IdeaRecord memory ideaRecord = IdeaRecord(value, uint32(block.number), false, ideaTxs, description);
        ideaRecords[ideaId] = ideaRecord;
        ++nextIdeaId;

        sponsorships[msg.sender][ideaId].contributedBalance = value;
        sponsorships[msg.sender][ideaId].isCreator = true;

        _mint(msg.sender, ideaId, msg.value, '');

        emit IdeaCreated(ideaRecord);
    }

    function sponsorIdea(uint256 ideaId) public payable {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);
        if (ideaId >= nextIdeaId || ideaId == 0) revert NonexistentIdeaId(ideaId);
        // revert if a new round should be started
        if (block.number - roundLength >= currentRoundInfo.startBlock) revert RoundIncomplete();
        
        // typecast values can contain all Ether in existence && quintillions of ideas per human on earth
        uint216 value = uint216(msg.value);
        uint96 id = uint96(ideaId);
        if (ideaRecords[id].isProposed) revert AlreadyProposed(ideaId);

        ideaRecords[id].totalFunding += value;
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

        // determine winners by checking balances

        //todo populate with winning txs & description
        NounsDAOV3Proposals.ProposalTxs memory txs;
        string memory description;

        /* address[] memory delegators = */ propLotCore.pushProposal(txs, description); // must return winning Delegations
        // pay Delegations.delegator proportional to their usable voting power
    }
}