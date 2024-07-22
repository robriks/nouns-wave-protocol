//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IPolymathTextRegular} from "src/SVG/fonts/IPolymathTextRegular.sol";
import {SSTORE2} from "solady/utils/SSTORE2.sol";

/// @title Polymath text regular font
/// @author modified @0x_beans code by @frog (warpcast)
/// @notice This font is forward-compatible with the FontRegistry project designed by 0xbeans
/// which is hosted and documented here: https://github.com/0xBeans/FontRegistry 
/// Since the FontRegistry project is not yet finalized and deployed to mainnet, Wave does not
/// rely on it as a dependency but wrote this contract to comply with the standard so it may
/// easily be added in the future when the FontRegistry is launched.
/// @dev Uses the Solady SSTORE2 mechanic rather than conventional contract storage despite
/// comfortably fitting within a single contract's bytecode (or storage) to maintain consistency
/// of the SSTORE2 pattern which other larger fonts will require.
contract PolymathTextRegular is IPolymathTextRegular {
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
