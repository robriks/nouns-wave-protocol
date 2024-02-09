// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.24;

/// @dev Interface for interacting with the Nouns ERC721 governance token with minimal deployment bytecode overhead
interface IERC721Checkpointable {
    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    /// @notice Returns the name of the ERC721 token
    function name() external view returns (string memory);
    /// @notice Defines decimals as per ERC-20 convention to make integrations with 3rd party governance platforms easier
    function decimals() external returns (uint8);
    /// @notice A record of votes checkpoints for each account, by index
    function checkpoints(address account, uint32 index) external view returns (Checkpoint memory);
    /// @notice The number of checkpoints for each account
    function numCheckpoints(address account) external returns (uint32);
    /// @notice The EIP-712 typehash for the contract's domain
    function DOMAIN_TYPEHASH() external view returns (bytes32);
    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    function DELEGATION_TYPEHASH() external view returns (bytes32);
    /// @notice A record of states for signing / validating signatures
    function nonces(address account) external view returns (uint256);
    /// @notice The votes a delegator can delegate, which is the current balance of the delegator.
    function votesToDelegate(address delegator) external view returns (uint96);
    /// @notice Overrides the standard `Comp.sol` delegates mapping to return delegator's own address if they haven't delegated.
    function delegates(address delegator) external view returns (address);
    /// @notice Delegate votes from `msg.sender` to `delegatee`
    function delegate(address delegatee) external;
    /// @notice Delegates votes from signatory to `delegatee`
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    /// @notice Gets the current votes balance for `account`
    function getCurrentVotes(address account) external view returns (uint96);
    /// @notice Determine the prior number of votes for an account as of a block number
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}
