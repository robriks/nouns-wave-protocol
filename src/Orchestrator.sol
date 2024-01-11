// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsDAOLogicV3} from "nouns-monorepo/governance/NounsDAOLogicV3.sol";
import {NounsDAOStorageV3} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";

contract Orchestrator {
    
    /*
      Constants
    */

    address constant NOUNS_EXECUTOR = 0x0BC3807Ec262cB779b38D65b38158acC3bfedE10;
    address payable public constant NOUNS_GOVERNOR = payable(address(0x6f3E6272A167e8AcCb32072d08E0957F9c79223d));
    address public constant NOUNS_TOKEN = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;
    address public constant DELEGATE_CASH = 0x00000000000000447e69651d841bD8D104Bed493;

    function propose() public {
        // NounsDAOStorageV3.StorageV3 storage ds;
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        string[] memory signatures = new string[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(0x0);
        values[0] = 1;
        signatures[0] = '';
        calldatas[0] = '';
        string memory test = 'yes';
        NounsDAOLogicV3(NOUNS_GOVERNOR).propose(targets, values, signatures, calldatas, test);
    }

    // todo: must inherit erc721receiver
}
