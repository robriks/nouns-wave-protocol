// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @title Sole `ProposalTxs` struct from the NounsDAOV3Proposals contract to save on imported bytecode

/// @dev Wave Protocol's IdeaTokenHub and Delegate contracts only rely on a single struct 
/// from the NounsDAOV3Proposals dependency so it is made available here without bytecode overhead
struct ProposalTxs {
    address[] targets;
    uint256[] values;
    string[] signatures;
    bytes[] calldatas;
}
