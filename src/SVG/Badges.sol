// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import "lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SSTORE2} from "solady/utils/SSTORE2.sol";

/// @title Badges
contract Badges is OwnableRoles {
    uint256 count = 0;
    mapping(uint256 => address) public shapes;

    constructor() {
        _initializeOwner(msg.sender);
    }

    function addShape(string calldata shapeSVG) public onlyOwner {
        shapes[count] = SSTORE2.write(bytes(shapeSVG));
        count++;
    }

    function addManyShapes(string[] calldata shapeSVGs) external onlyOwner {
        for (uint256 i = 0; i < shapeSVGs.length; i++) {
            addShape(shapeSVGs[i]);
        }
    }

     function getShape(uint256 index) external view returns (string memory) {
        return string(abi.encodePacked(SSTORE2.read(shapes[index])));
    }
}
