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

    /// @notice `type(uint96).max` size provides a large buffer for tokenIds, overflow is unrealistic
    struct Sponsorship {
        address sponsor;
        uint96 ideaId;
        SponsorshipParams params;
    }

    struct SponsorshipParams {
        uint224 amount;
        uint32 blockNumber;
    }

    error BelowMinimumSponsorshipAmount(uint256 value);

    /*
      Constants
    */

    /// @dev The length of time for a round in blocks, marking the block number where winning ideas are chosen 
    uint256 public constant roundLength = 1209600;
    uint256 public constant minSponsorshipAmount = 0.001 ether;
    IPropLot private immutable propLotCore;

    /*
      Storage
    */

    uint256 nextIdeaId;

    mapping (uint96 => uint256) ideaTotalFunding;
    mapping (address => mapping (uint96 => SponsorshipParams)) sponsorships;

    constructor(string memory uri) ERC1155(uri) {
        propLotCore = IPropLot(msg.sender);
        ++nextIdeaId;
    }

    function createIdea(NounsDAOV3Proposals.ProposalTxs memory ideaTxs) public payable {
        //todo
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);
        
        uint96 ideaId = uint96(nextIdeaId);
        ++nextIdeaId;
        ideaTotalFunding[ideaId] += msg.value;

        // typecasting `msg.value` to `uint224` is safe as it can fit all ETH in existence barring major protocol change
        SponsorshipParams memory params = SponsorshipParams(uint224(msg.value), uint32(block.number));
        Sponsorship memory sponsorship = Sponsorship(msg.sender, ideaId, params);
        

        _mint(msg.sender, ideaId, 1, abi.encode(params));
    }

    function sponsorIdea(uint256 ideaId) public payable {
        if (msg.value < minSponsorshipAmount) revert BelowMinimumSponsorshipAmount(msg.value);

        //todo
    }


    function finalizeRound() external {
        //todo populate with winning txs & description
        NounsDAOV3Proposals.ProposalTxs memory txs;
        string memory description;

        // check that roundLength has passed
        // determine winners by checking balances
        propLotCore.pushProposal(txs, description); // must return winning Delegations
        // pay Delegations.delegator proportional to their usable voting power
    }
}