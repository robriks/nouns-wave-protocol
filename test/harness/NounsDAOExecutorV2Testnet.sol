import {NounsDAOExecutorV2} from "nouns-monorepo/governance/NounsDAOExecutorV2.sol";

contract NounsDAOExecutorV2Testnet is NounsDAOExecutorV2 {

    function initialize(address admin_, uint256 delay_) public virtual override initializer {
        uint256 TESTNET_MINIMUM_DELAY = 0;
        require(delay_ >= TESTNET_MINIMUM_DELAY, 'NounsDAOExecutor::constructor: Delay must exceed minimum delay.');
        require(delay_ <= MAXIMUM_DELAY, 'NounsDAOExecutor::setDelay: Delay must not exceed maximum delay.');

        admin = admin_;
        delay = delay_;
    }
}