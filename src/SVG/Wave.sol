// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ColorStorage} from "./ColorStorage.sol";

contract Wave is ColorStorage {
    function constructWavePart1(string memory color1, string memory color2) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "<path d='M23 2H19V3H23V2Z' fill='",
                color1,
                "'/><path d='M25 3H15V4H25V3Z' fill='",
                color1,
                "'/><path d='M15 4H13V5H15V4Z' fill='",
                color1,
                "'/><path d='M16 4H15V5H16V4Z' fill='",
                color2,
                "'/><path d='M26 4H16V5H26V4Z' fill='",
                color1,
                "'/><path d='M17 5H12V6H17V5Z' fill='",
                color1,
                "'/><path d='M19 5H17V6H19V5Z' fill='",
                color2
            )
        );
    }

    function constructWavePart2(string memory color1, string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M21 5H19V6H21V5Z' fill='",
                color3,
                "'/><path d='M22 5H21V6H22V5Z' fill='",
                color2,
                "'/><path d='M24 5H22V6H24V5Z' fill='",
                color1,
                "'/><path d='M25 5H24V6H25V5Z' fill='",
                color2,
                "'/><path d='M27 5H25V6H27V5Z' fill='",
                color1,
                "'/><path d='M13 6H11V7H13V6Z' fill='",
                color1,
                "'/><path d='M15 6H13V7H15V6Z' fill='",
                color2
            )
        );
    }

    function constructWavePart3(string memory color1, string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M16 6H15V7H16V6Z' fill='",
                color1,
                "'/><path d='M18 6H16V7H18V6Z' fill='",
                color2,
                "'/><path d='M19 6H18V7H19V6Z' fill='",
                color3,
                "'/><path d='M24 6H19V7H24V6Z' fill='",
                color2,
                "'/><path d='M26 6H24V7H26V6Z' fill='",
                color1,
                "'/><path d='M27 6H26V7H27V6Z' fill='",
                color2,
                "'/><path d='M28 6H27V7H28V6Z' fill='",
                color1
            )
        );
    }

    function constructWavePart4(string memory color1, string memory color2) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M12 7H10V8H12V7Z' fill='",
                color1,
                "'/><path d='M14 7H12V8H14V7Z' fill='",
                color2,
                "'/><path d='M15 7H14V8H15V7Z' fill='",
                color1,
                "'/><path d='M17 7H15V8H17V7Z' fill='",
                color2,
                "'/><path d='M18 7H17V8H18V7Z' fill='",
                color1,
                "'/><path d='M21 7H18V8H21V7Z' fill='",
                color2,
                "'/><path d='M22 7H21V8H22V7Z' fill='",
                color1
            )
        );
    }

    function constructWavePart5(string memory color1, string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M23 7H22V8H23V7Z' fill='",
                color3,
                "'/><path d='M25 7H23V8H25V7Z' fill='",
                color2,
                "'/><path d='M28 7H25V8H28V7Z' fill='",
                color1,
                "'/><path d='M11 8H10V9H11V8Z' fill='",
                color1,
                "'/><path d='M14 8H11V9H14V8Z' fill='",
                color2,
                "'/><path d='M15 8H14V9H15V8Z' fill='",
                color1,
                "'/><path d='M17 8H15V9H17V8Z' fill='",
                color2
            )
        );
    }

    function constructWavePart6(string memory color1, string memory color2) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M18 8H17V9H18V8Z' fill='",
                color1,
                "'/><path d='M20 8H18V9H20V8Z' fill='",
                color2,
                "'/><path d='M21 8H20V9H21V8Z' fill='",
                color1,
                "'/><path d='M27 8H21V9H27V8Z' fill='",
                color2,
                "'/><path d='M28 8H27V9H28V8Z' fill='",
                color1,
                "'/><path d='M11 9H9V10H11V9Z' fill='",
                color1,
                "'/><path d='M13 9H11V10H13V9Z' fill='",
                color2
            )
        );
    }

    function constructWavePart7(string memory color1, string memory color2) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M14 9H13V10H14V9Z' fill='",
                color1,
                "'/><path d='M16 9H14V10H16V9Z' fill='",
                color2,
                "'/><path d='M17 9H16V10H17V9Z' fill='",
                color1,
                "'/><path d='M20 9H17V10H20V9Z' fill='",
                color2,
                "'/><path d='M21 9H20V10H21V9Z' fill='",
                color1,
                "'/><path d='M23 9H21V10H23V9Z' fill='",
                color2,
                "'/><path d='M27 9H26V10H27V9Z' fill='",
                color2
            )
        );
    }

    function constructWavePart8(string memory color1, string memory color2) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M28 9H27V10H28V9Z' fill='",
                color1,
                "'/><path d='M10 10H9V11H10V10Z' fill='",
                color1,
                "'/><path d='M13 10H10V11H13V10Z' fill='",
                color2,
                "'/><path d='M14 10H13V11H14V10Z' fill='",
                color1,
                "'/><path d='M16 10H14V11H16V10Z' fill='",
                color2,
                "'/><path d='M17 10H16V11H17V10Z' fill='",
                color1,
                "'/><path d='M22 10H17V11H22V10Z' fill='",
                color2
            )
        );
    }

    function constructWavePart9(string memory color1, string memory color2) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M27 10H26V11H27V10Z' fill='",
                color1,
                "'/><path d='M9 11H8V12H9V11Z' fill='",
                color1,
                "'/><path d='M22 11H9V12H22V11Z' fill='",
                color2,
                "'/><path d='M9 12H8V13H9V12Z' fill='",
                color1,
                "'/><path d='M22 12H9V13H22V12Z' fill='",
                color2,
                "'/><path d='M9 13H7V14H9V13Z' fill='",
                color1,
                "'/><path d='M22 13H9V14H22V13Z' fill='",
                color2
            )
        );
    }

    function constructWavePart10(string memory color1, string memory color2) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M8 14H7V15H8V14Z' fill='",
                color1,
                "'/><path d='M22 14H8V15H22V14Z' fill='",
                color2,
                "'/><path d='M7 15H6V16H7V15Z' fill='",
                color1,
                "'/><path d='M22 15H7V16H22V15Z' fill='",
                color2,
                "'/><path d='M7 16H6V17H7V16Z' fill='",
                color1,
                "'/><path d='M22 16H7V17H22V16Z' fill='",
                color2,
                "'/><path d='M6 17H5V18H6V17Z' fill='",
                color1
            )
        );
    }

    function constructWavePart11(string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M13 17H6V18H13V17Z' fill='",
                color2,
                "'/><path d='M14 17H13V18H14V17Z' fill='",
                color3,
                "'/><path d='M16 17H14V18H16V17Z' fill='",
                color2,
                "'/><path d='M17 17H16V18H17V17Z' fill='",
                color3,
                "'/><path d='M20 17H17V18H20V17Z' fill='",
                color2,
                "'/><path d='M21 17H20V18H21V17Z' fill='",
                color3,
                "'/><path d='M22 17H21V18H22V17Z' fill='",
                color2
            )
        );
    }

    function constructWavePart12(string memory color1, string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M6 18H5V19H6V18Z' fill='",
                color1,
                "'/><path d='M10 18H6V19H10V18Z' fill='",
                color2,
                "'/><path d='M11 18H10V19H11V18Z' fill='",
                color1,
                "'/><path d='M13 18H11V19H13V18Z' fill='",
                color2,
                "'/><path d='M14 18H13V19H14V18Z' fill='",
                color3,
                "'/><path d='M17 18H14V19H17V18Z' fill='",
                color2,
                "'/><path d='M18 18H17V19H18V18Z' fill='",
                color3
            )
        );
    }

    function constructWavePart13(string memory color1, string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M21 18H18V19H21V18Z' fill='",
                color2,
                "'/><path d='M22 18H21V19H22V18Z' fill='",
                color3,
                "'/><path d='M23 18H22V19H23V18Z' fill='",
                color2,
                "'/><path d='M2 19H1V20H2V19Z' fill='",
                color1,
                "'/><path d='M5 19H4V20H5V19Z' fill='",
                color1,
                "'/><path d='M9 19H5V20H9V19Z' fill='",
                color2,
                "'/><path d='M10 19H9V20H10V19Z' fill='",
                color1
            )
        );
    }

    function constructWavePart14(string memory color1, string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                "'/><path d='M14 19H10V20H14V19Z' fill='",
                color2,
                "'/><path d='M15 19H14V20H15V19Z' fill='",
                color3,
                "'/><path d='M18 19H15V20H18V19Z' fill='",
                color2,
                "'/><path d='M20 19H18V20H20V19Z' fill='",
                color3,
                "'/><path d='M25 19H20V20H25V19Z' fill='",
                color2,
                "'/><path d='M4 20H2V21H4V20Z' fill='",
                color1,
                "'/><path d='M26 20H4V21H26V20Z' fill='",
                color2
            )
        );
    }

    function constructWaveGroup1(string memory color1, string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                constructWavePart1(color1, color2),
                constructWavePart2(color1, color2, color3),
                constructWavePart3(color1, color2, color3),
                constructWavePart4(color1, color2),
                constructWavePart5(color1, color2, color3),
                constructWavePart6(color1, color2),
                constructWavePart7(color1, color2)
            )
        );
    }

    function constructWaveGroup2(string memory color1, string memory color2, string memory color3) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                constructWavePart8(color1, color2),
                constructWavePart9(color1, color2),
                constructWavePart10(color1, color2),
                constructWavePart11(color2, color3),
                constructWavePart12(color1, color2, color3),
                constructWavePart13(color1, color2, color3),
                constructWavePart14(color1, color2, color3)
            )
        );
    }

    function constructWave(uint256 tokenId, string memory scale, string memory xPos, string memory yPos) private view returns (string memory) {
        string[] memory colors = _pluckColor(tokenId);

        return string(
            abi.encodePacked(
                "<g transform='scale(",
                scale,
                ") translate(",
                xPos,
                ", ",
                yPos,
                ")'>",
                constructWaveGroup1(colors[0], colors[1], colors[2]),
                constructWaveGroup2(colors[0], colors[1], colors[2]),
                "'/></g>"
            )
        );
    }

    function constructWaveScene(uint256 tokenId) public view returns (string memory) {
        return string(
            abi.encodePacked(
                constructWave(tokenId, "4", "1", "42"),
                constructWave(tokenId, "3.8", "10", "42"),
                constructWave(tokenId, "3.6", "15", "42")
            )
        );
    }
}
