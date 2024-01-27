// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NounsDAOProxyV3} from "nouns-monorepo/governance/NounsDAOProxyV3.sol";
import {NounsDAOLogicV3} from "nouns-monorepo/governance/NounsDAOLogicV3.sol";
import {NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {ERC721Checkpointable} from "nouns-monorepo/base/ERC721Checkpointable.sol";
import {PropLotCore} from "../../src/PropLotCore.sol";

contract OrchestratorTest is Test {

    PropLotCore public propLotCore;
    NounsDAOLogicV3 public nounsGovernorProxy;
    NounsTokenLike public nounsToken;

    address ideaTokenHub;
    address payable nounsGovernor;
    address nounsTokenAddress;

    function setUp() public {
        //todo
    }

    //function test_pushProposal()
    //function test_delegateBySig()
    //function test_delegateByDelegateCall
    //function test_proposalThresholdIncrease()
    
    //function test_disqualifiedDelegationIndices()
    //function test_deleteDelegations()
    //function test_deleteDelegationsZeroMembers()
    //function test_simulateCreate2()
    //function test_getDelegateAddress()
    //function test_createDelegate()
    //function test_setActiveDelegation()
    //function test_computeNounsDelegationDigest
}