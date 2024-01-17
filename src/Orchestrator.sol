// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsDAOLogicV3} from "nouns-monorepo/governance/NounsDAOLogicV3.sol";
import {NounsDAOStorageV3, NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {ERC721Checkpointable} from "nouns-monorepo/base/ERC721Checkpointable.sol";
import {Delegate} from "./Delegate.sol";

contract Orchestrator {
    // Nounder calls this contract to generate a proxy and delegates voting power to it
    // proxy contract contains only two functions: propose and withdraw
    // Any address can then use the proposal power of the Nounder's proxy via this contract as intermediary
    // todo: must inherit erc721receiver if receiving tokens to enable delegation of partial vote balance

    /*
      Structs
    */

    /// @param delegator Only token holder addresses are stored since Delegates can be derived
    /// @param blockDelegated Block at which a Noun was delegated, used for payout calculation.
    /// Only records delegations performed via this contract, ie not direct delegations on Nouns token
    /// @param votingPower Voting power can safely be stored in a uint16 as the type's maximum 
    /// represents 179.5 years of Nouns token supply issuance (at a rate of one per day)
    /// @param supplementId Identifier used to combine a delegation with votingPower below the proposalThreshold
    /// with another delegation to supplement its votingPower by together delegating to the same proxy
    struct Delegation {
        address delegator;
        uint64 blockDelegated;
        uint16 votingPower;
        uint16 supplementId;
    }

    /*
      Errors + Events
    */

    error Create2Failure();
    error OnlyIdeaContract();
    error ECDSAInvalidSignatureLength(uint256 length);
    event DelegateCreated(address nounder, address delegate);
    event DelegationActivated(Delegation activeDelegation);
    event DelegationDeleted(Delegation inactiveDelegation);
    
    /*
      Constants
    */

    address public immutable ideaTokenHub;
    address payable public immutable nounsGovernor;
    address public immutable nounsToken;

    /*
      Storage
    */

    Delegation[] private _activeDelegations;
    //todo mapping (address => address) public _supplementDelegations;

    constructor(address ideaTokenHub_, address payable nounsGovernor_, address nounsToken_) {
        ideaTokenHub = ideaTokenHub_;
        nounsGovernor = nounsGovernor_;
        nounsToken = nounsToken_;
    }

    // proposals -> 1155s that non-nounders can mint for a fee in support of (provenance + liquidity)
    // 1155 w/ most mints wins onchain, two week proposal 'ritual' to push ideas onchain based on highest mints
    // split sum of minting fees between existing noun delegates in a claim() func
    // non-winning tokens w/ existing votes can roll over into following two week periods
    // enable pooling of delegation power so that eg 2 nounders who only own 1 noun each can pool their power to propose  
    // todo: handle updates of votingPower changes
    // todo: user create interfaces for ERC721Checkpointable and ERC721Votes

    /// @dev Pushes the winning proposal onto the `nounsGovernor` to be voted on in the Nouns governance ecosystem
    /// Checks for changes in delegation state on `nounsToken` contract and updates PropLot recordkeeping accordingly
    /// @notice May only be called by the PropLot's ERC1155 Idea token hub at the conclusion of each 2-week round
    function pushProposal(
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata calldatas,
        string calldata description
    ) public payable {
        // todo check for external rogue redelegations and update state
        if (msg.sender != ideaTokenHub) revert OnlyIdeaContract(); 
        _delegate.pushProposal(nounsGovernor, targets, values, signatures, calldatas, description);
    }

    /// @dev Simultaneously creates a delegate if it doesn't yet exist and grants voting power to the delegate
    /// in a single function call. This is the most convenient option standard wallets using EOA private keys
    /// @notice The Nouns ERC721Checkpointable implementation only supports standard EOA ECDSA signatures and thus
    /// does not support smart contract signatures. In that case, `delegate()` must be called on the Nouns contract directly
    // todo: use delegatecall to support smart contract wallets? would need isValidSignature() check before nounsToken.delegate()
    function delegateBySig(uint256 nonce, uint256 expiry, bytes calldata signature) public {
        if (signature.length != 65) revert ECDSAInvalidSignatureLength(signature.length);
        
        //todo: check if getPriorVotes(msg.sender, block.number) is < proposalThreshold, add to supplement mapping
        address delegate = getDelegateAddress(msg.sender);
        if (delegate.code.length == 0) {
            createDelegate();
        }

        Delegate memory delegation = ({msg.sender, block.number, votingPower, supplementId});
        _setActiveDelegation(delegation);

        ERC721Checkpointable(nounsToken).delegateBySig(
            delegate, 
            nonce, 
            expiry, 
            uint8(bytes1(signature[64])),
            bytes32(signature[0:32]),
            bytes32(signature[32:64])
        );
    }

    function createDelegate() public returns (address delegate) {
        delegate = address(new Delegate{salt: bytes32(uint256(uint160(msg.sender)))}(address(this)));
        if (delegate == address(0x0)) revert Create2Failure();
        
        emit DelegateCreated(msg.sender, delegate);
    }
    
    function getDelegateAddress(address nounder) public view returns (address delegate) {
        //todo if (supplementDelegates[delegate] != address(0x0) return supplementDelegates[nouner]; 

        bytes32 creationCodeHash = keccak256(type(Delegate).creationCode);
        delegate = _simulateCreate2(bytes32(uint256(uint160(nounder))), creationCodeHash);
    }

    function _purgeInactiveDelegations() internal {
        unchecked {
            for (uint256 i; i < _activeDelegations.length; ++i) {
                address nounder = _activeDelegations[i].delegator;
                address delegate = getDelegateAddress(nounder);
                
                uint256 numInactiveNonLastIndices;
                if (ERC721Checkpointable(nounsToken).delegates(nounder) != delegate) {
                    // cache inactive delegation in memory for later event emission
                    Delegation memory inactiveDelegation = _activeDelegations[i];

                    uint256 lastIndex = _activeDelegations.length - 1;
                    if (i < lastIndex) {
                        Delegation memory lastDelegation = _activeDelegations[lastIndex];
                        _activeDelegations[i] = lastDelegation;
                        ++numInactiveNonLastIndices;
                    }

                    emit DelegationDeleted(inactiveDelegation);
                }

                uint256 startIndex = _activeDelegations.length - 1;
                for (uint256 j; j < numInactiveNonLastIndices; ++j) {
                    delete _activeDelegations[startIndex - j];
                    // if (_supplementDelegations[nounder] != address(0x0)) delete _supplementDelegations[nounder];
                }
            }
        }
    }

    function _setActiveDelegation(Delegation memory _delegation) internal {
        _activeDelegations.push(_delegation);

        emit DelegationActivated(_delegation);
    }

    function _simulateCreate2(bytes32 _salt, bytes32 _creationCodeHash) internal view returns (address simulatedDeployment) {
        assembly {
            let ptr := mload(0x40) // instantiate free mem pointer

            mstore(add(ptr, 0x0b), 0xff) // insert single byte create2 constant at 11th offset (starting from 0)
            mstore(ptr, address()) // insert 20-byte deployer address at 12th offset
            mstore(add(ptr, 0x20), _salt) // insert 32-byte salt at 32nd offset
            mstore(add(ptr, 0x40), _creationCodeHash) // insert 32-byte creationCodeHash at 64th offset

            // hash all inserted data, which is 85 bytes long, starting from 0xff constant at 11th offset
            simulatedDeployment := keccak256(add(ptr, 0x0b), 85)
        }
    }
}
