// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ECDSA} from "nouns-monorepo/external/openzeppelin/ECDSA.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {NounsDAOStorageV3, NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {Delegate} from "src/Delegate.sol";
import {PropLot} from "src/PropLot.sol";
import {console2} from "forge-std/console2.sol";

/// @dev PropLot harness contract exposing all internal functions externally for testing
contract PropLotHarness is PropLot {

    address self;
    bytes32 creationCodeHash;
    constructor(address ideaTokenHub_, INounsDAOLogicV3 nounsGovernor_, IERC721Checkpointable nounsToken_)
        PropLot(ideaTokenHub_, nounsGovernor_, nounsToken_) 
    {
        self = address(this);
        creationCodeHash = keccak256(abi.encodePacked(type(Delegate).creationCode, bytes32(uint256(uint160(self)))));

    }
    
    function __self() public view returns (address) {
        return self;
    }
    function __creationCodeHash() public view returns (bytes32) {
        return creationCodeHash;
    }
    function findDelegateId(uint256 _minRequiredVotes, bool _isSupplementary) public view returns (uint256 delegateId) {
        return _findDelegateId(_minRequiredVotes, _isSupplementary);
    }
    function findProposerDelegate(uint256 _minRequiredVotes) public view returns (address proposerDelegate) {
        return _findProposerDelegate(_minRequiredVotes);
    }
    function disqualifiedDelegationIndices(uint256 _minRequiredVotes) public returns (uint256[] memory) {
        return _disqualifiedDelegationIndices(_minRequiredVotes);
    }
    function inspectCheckpoints(address _nounder, address _delegate, uint256 _currentCheckpoints, uint256 _numCheckpointsSnapshot, uint256 _votingPower, uint256 _minRequiredVotes) public view returns (bool _disqualify) {
        return _inspectCheckpoints(_nounder, _delegate, _currentCheckpoints, _numCheckpointsSnapshot, _votingPower, _minRequiredVotes);
    }
    function deleteDelegations(uint256[] memory _indices) public {
        _deleteDelegations(_indices);
    }
    function getOptimisticDelegations() public view returns (Delegation[] memory) {
        return _getOptimisticDelegations();
    }
    function setOptimisticDelegation(Delegation memory _delegation) public {
        _setOptimisticDelegation(_delegation);
    }
    function isEligibleProposalState(uint256 _latestProposal) public view returns (bool) {
        return _isEligibleProposalState(_latestProposal);
    }
    function simulateCreate2(bytes32 _salt, bytes32 _creationCodeHash) public view returns (address simulatedDeployment) {
        return _simulateCreate2(_salt, _creationCodeHash);
    }
}
