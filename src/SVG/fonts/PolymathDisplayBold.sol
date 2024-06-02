//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IFont} from "../interfaces/IFont.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {SSTORE2} from "solady/utils/SSTORE2.sol";

/// @title Example of uploading a font on-chain
/// @author @0x_beans
contract ExampleFont is OwnableRoles, IFont {
    /*==============================================================
    ==                     Custom Font Variables                  ==
    ==============================================================*/

    // our font is 12KB
    // contract storage is < 24KB
    uint256 public constant FONT_PARTITION = 0;

    // addresses where font chunks are stored
    mapping(uint256 => address) public files;

    /*==============================================================
    ==                         IFont Info                         ==
    ==============================================================*/

    address public fontUploader = msg.sender;

    string public constant fontName = "polymath-display";

    string public constant fontFormatType = "otf";

    string public constant fontWeight = "bold";

    string public constant fontStyle = "normal";

    /*==============================================================
    ==                      Custom Font Logic                     ==
    ==============================================================*/

    function saveFile(uint256 index, string calldata fileContent)
        external
        onlyOwner
    {
        files[index] = SSTORE2.write(bytes(fileContent));
    }

    // IMPORTANT: MUST RENOUNCE OWNERSHIP SO FONT DATA IS COMPLETELY IMMUTABLE
    function finalizeFont() external onlyOwner {
        renounceOwnership();
    }

    /*==============================================================
    ==                     IFont Implementation                   ==
    ==============================================================*/

    function getFont() external view returns (string memory) {
        return string(abi.encodePacked(SSTORE2.read(files[0])));
    }
}
