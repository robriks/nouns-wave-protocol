import {console2, Test} from "forge-std/Test.sol";
import { StringSplitter } from "../../src/SVG/Splitter.sol";

// forge t --mc StringSplitterTest -vvvv
contract StringSplitterTest is Test {
    StringSplitter splitter;

    function setUp() public {
        vm.startPrank(address(123));
        splitter = new StringSplitter();
        vm.stopPrank();
    }


    function test_split() public {
        // string memory title = "Enjoy nouns with probe.wtf";
        string memory title = "Heal Noun O'Clock; Full Spec and Economic Audit of % Exit, An Arbitrage-Free Forking Mechanic";
        string[] memory words = splitter.splitStringByMaxLength(title, 26);
    }
}
