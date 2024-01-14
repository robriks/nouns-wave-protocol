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

    function propose(address payable governor) external {
        if (msg.sender != orchestrator) revert NotOrchestrator(msg.sender);

        // todo: implement placeholders, move arrays to func args
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(0x0);
        values[0] = 1;
        signatures[0] = '';
        calldatas[0] = '';
        string memory test = 'yes';
        NounsDAOLogicV3(governor).propose(targets, values, signatures, calldatas, test);
    }
}