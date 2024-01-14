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

    function propose(
        address payable governor, 
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata signatures,
        bytes[] calldata calldatas,
        string calldata description
    ) external {
        if (msg.sender != orchestrator) revert NotOrchestrator(msg.sender);
        
        NounsDAOLogicV3(governor).propose(targets, values, signatures, calldatas, description);
    }
}