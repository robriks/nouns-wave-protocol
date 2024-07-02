//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IFont} from "FontRegistry/src/interfaces/IFont.sol";
import {SSTORE2} from "solady/utils/SSTORE2.sol";

/// @title Polymath text regular font
/// @author modified @0x_beans code by @frog (warpcast)
/// @notice This font fits into a single contract's bytecode with plenty of room to spare.
/// As a result it doesn't actually need to be split into multiple chunks via SSTORE2 and
/// could instead be put in conventional contract storage. However, since this font will be
/// rendered for free in a view context for Wave Protocol, we choose to maintain consistency
/// of the SSTORE2 pattern (which other larger fonts will require) so this font may serve
/// as an example implementation for future fonts that follow
contract PolymathTextRegular is IFont {
    constructor(string memory fontData_) {
        // PolymathText font is 12kb which fits in a single contract's bytecode (using Solady's SSTORE2)
        _saveFile(FONT_PARTITION, fontData_);
    }

    /*==============================================================
    ==                     Custom Font Variables                  ==
    ==============================================================*/

    // since this font is 12KB and contract bytecode size limit is 24KB, only one partition needed
    uint256 public constant FONT_PARTITION = 0;

    // addresses where font chunks normally would be stored
    mapping(uint256 => address) public files;

    /*==============================================================
    ==                         IFont Info                         ==
    ==============================================================*/

    address public immutable fontUploader = msg.sender;

    string public constant fontName = "polymath-text";

    string public constant fontFormatType = "otf";

    string public constant fontWeight = "normal";

    string public constant fontStyle = "normal";

    bytes32 public constant fontRegistryKey = keccak256(abi.encodePacked(fontName));

    /*==============================================================
    ==                      Custom Font Logic                     ==
    ==============================================================*/

    // invoked in the constructor to bypass need for access control & multiple transactions
    function _saveFile(uint256 index, string memory fileContent) internal {
        files[index] = SSTORE2.write(bytes(fileContent));
    }

    /*==============================================================
    ==                     IFont Implementation                   ==
    ==============================================================*/

    function getFont() external view returns (string memory) {
        return string(SSTORE2.read(files[FONT_PARTITION]));
    }
}
