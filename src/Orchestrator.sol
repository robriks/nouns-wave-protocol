// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IDelegateRegistry} from "delegate-registry/src/IDelegateRegistry.sol";

contract Orchestrator {
    
    /*
      Constants
    */

    address constant NOUNS_EXECUTOR = 0x0BC3807Ec262cB779b38D65b38158acC3bfedE10;
    address constant NOUNS_GOVERNOR = payable(address(0x6f3E6272A167e8AcCb32072d08E0957F9c79223d));
    address constant NOUNS_TOKEN = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;
    address constant DELEGATE_CASH = 0x00000000000000447e69651d841bD8D104Bed493;
}
