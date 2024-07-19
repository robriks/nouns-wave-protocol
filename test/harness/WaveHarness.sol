// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ECDSA} from "nouns-monorepo/external/openzeppelin/ECDSA.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {NounsDAOStorageV3, NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {Delegate} from "src/Delegate.sol";
import {Wave} from "src/Wave.sol";
import {console2} from "forge-std/console2.sol";

/// @dev Wave harness contract exposing all internal functions externally for testing
contract WaveHarness is Wave {
    address self;
    bytes32 creationCodeHash;

    constructor() Wave() {}

    function initialize(
        address ideaTokenHub_,
        address nounsGovernor_,
        address nounsToken_,
        uint256 minSponsorshipAmount_,
        uint256 waveLength_,
        address renderer_
    ) public override {
        super.initialize(ideaTokenHub_, nounsGovernor_, nounsToken_, minSponsorshipAmount_, waveLength_, renderer_);
        self = address(this);
        creationCodeHash = keccak256(abi.encodePacked(type(Delegate).creationCode, bytes32(uint256(uint160(self)))));
    }

    function __self() public view returns (address) {
        return self;
    }

    function __creationCodeHash() public view returns (bytes32) {
        return creationCodeHash;
    }

    function findDelegateId(uint256 _minRequiredVotes, bool _isSupplementary)
        public
        view
        returns (uint256 delegateId)
    {
        return _findDelegateId(_minRequiredVotes, _isSupplementary);
    }

    function disqualifiedDelegationIndices() public view returns (uint256[] memory) {
        return _disqualifiedDelegationIndices();
    }

    function isDisqualified(address _nounder, address _delegate, uint256 _votingPower)
        public
        view
        returns (bool _disqualify)
    {
        return _isDisqualified(_nounder, _delegate, _votingPower);
    }

    function deleteDelegations(uint256[] memory _indices) public {
        _deleteDelegations(_indices);
    }

    function setOptimisticDelegation(Delegation memory _delegation) public {
        _setOptimisticDelegation(_delegation);
    }

    function isEligibleProposalState(uint256 _latestProposal) public view returns (bool) {
        return _isEligibleProposalState(_latestProposal);
    }

    function simulateCreate2(bytes32 _salt, bytes32 _creationCodeHash)
        public
        view
        returns (address simulatedDeployment)
    {
        return _simulateCreate2(_salt, _creationCodeHash);
    }
}