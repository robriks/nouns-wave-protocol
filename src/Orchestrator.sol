// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsDAOLogicV3} from "nouns-monorepo/governance/NounsDAOLogicV3.sol";
import {NounsDAOStorageV3} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {Delegate} from "./Delegate.sol";

contract Orchestrator {
    // Nounder calls this contract to generate a proxy and delegates voting power to it
    // proxy contract contains only two functions: propose and withdraw
    // Any address can then use the proposal power of the Nounder's proxy via this contract as intermediary
    
    error Create2Failure();
    event DelegateCreated(address nounder, address delegate);
    /*
      Constants
    */

    address constant NOUNS_EXECUTOR = 0x0BC3807Ec262cB779b38D65b38158acC3bfedE10;
    address payable public constant NOUNS_GOVERNOR = payable(address(0x6f3E6272A167e8AcCb32072d08E0957F9c79223d));
    address public constant NOUNS_TOKEN = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;

    // todo: temporary placeholder
    Delegate _delegate;

    function propose() public {
        _delegate.propose(NOUNS_GOVERNOR);
    }

    function createDelegate() public returns (address delegate) {
        delegate = address(new Delegate{salt: bytes32(uint256(uint160(msg.sender)))}(address(this)));
        if (delegate == address(0x0)) revert Create2Failure();
        emit DelegateCreated(msg.sender, delegate);

        //todo temporary placeholder
        _delegate = Delegate(delegate);
    }
    
    function getDelegateAddress() public view returns (address delegate) {
        bytes32 creationCodeHash = keccak256(type(Delegate).creationCode);
        _simulateCreate2(bytes32(uint256(uint160(msg.sender))), creationCodeHash);
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

    // todo: must inherit erc721receiver if receiving tokens to enable delegation of partial vote balance
}
