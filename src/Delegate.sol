// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsDAOLogicV3} from "nouns-monorepo/governance/NounsDAOLogicV3.sol";
import {NounsDAOStorageV3} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";

contract Delegate {
    error NotOrchestrator(address caller);

    address immutable orchestrator;

    constructor(address _orchestrator) {
        orchestrator = _orchestrator;
    }

    
    function pushProposal(
        address payable governor,
        NounsDAOV3Proposals.ProposalTxs calldata txs, 
        string calldata description
    ) external {
        if (msg.sender != orchestrator) revert NotOrchestrator(msg.sender);
        
        NounsDAOLogicV3(governor).propose(txs.targets, txs.values, txs.signatures, txs.calldatas, description);
    }
}
