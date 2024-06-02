// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract StringSplitter {

    // Function to split a string into words
    function splitIntoWords(string memory str) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        uint256 wordCount = 1;

        // Count the number of words
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == " ") {
                wordCount++;
            }
        }

        string[] memory words = new string[](wordCount);
        uint256 currentWordIndex = 0;
        bytes memory currentWord = new bytes(strBytes.length);
        uint256 currentWordLength = 0;

        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == " ") {
                words[currentWordIndex] = string(copyBytes(currentWord, currentWordLength));
                currentWordIndex++;
                currentWordLength = 0;
            } else {
                currentWord[currentWordLength] = strBytes[i];
                currentWordLength++;
            }
        }
        words[currentWordIndex] = string(copyBytes(currentWord, currentWordLength));

        return words;
    }

    // Function to copy bytes
    function copyBytes(bytes memory source, uint256 length) internal pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = source[i];
        }
        return result;
    }

    // Function to split string by max length without cutting words
    function splitStringByMaxLength(string memory str, uint256 maxLength) public pure returns (string[] memory) {
        string[] memory words = splitIntoWords(str);
        uint256 currentLength = 0;
        uint256 currentSegmentIndex = 0;
        bytes memory currentSegment = new bytes(maxLength);

        string[] memory tempSegments = new string[](words.length);

        for (uint256 i = 0; i < words.length; i++) {
            bytes memory wordBytes = bytes(words[i]);
            if (currentLength + wordBytes.length + (currentLength == 0 ? 0 : 1) > maxLength) {
                tempSegments[currentSegmentIndex] = string(copyBytes(currentSegment, currentLength));
                currentSegmentIndex++;
                currentLength = 0;
                currentSegment = new bytes(maxLength);
            }
            if (currentLength != 0) {
                currentSegment[currentLength] = " ";
                currentLength++;
            }
            for (uint256 j = 0; j < wordBytes.length; j++) {
                currentSegment[currentLength] = wordBytes[j];
                currentLength++;
            }
        }
        if (currentLength > 0) {
            tempSegments[currentSegmentIndex] = string(copyBytes(currentSegment, currentLength));
        }

        string[] memory result = new string[](currentSegmentIndex + 1);
        for (uint256 i = 0; i <= currentSegmentIndex; i++) {
            result[i] = tempSegments[i];
        }

        return result;
    }
}
