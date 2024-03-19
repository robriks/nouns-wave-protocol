import {console2, Test} from "forge-std/Test.sol";
import {Renderer} from "../src/SVG/Renderer.sol";

contract RendererTest is Test {
    Renderer public renderer;

    function setUp() public {
        // replace with proplot contract
        renderer = new Renderer(address(this));
    }

    function test_generateSVG() public {
        console2.log(address(renderer));
        Renderer.SVGParams memory params = Renderer.SVGParams(1, "00442a");
        string memory svg = renderer.generateSVG(params);
        console2.log(svg);
    }
}
