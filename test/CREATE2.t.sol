// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IWave} from "src/interfaces/IWave.sol";
import {Wave} from "src/Wave.sol";
import {IdeaTokenHub} from "../src/IdeaTokenHub.sol";

/// @dev Obtains the 32-byte hash of relevant Wave Protocol contracts for use with Create2Crunch
/// for mining vanity address salts
contract CREATE2Test is Test {

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
    }

    function test_getIdeaTokenHubHash() public {
        vm.selectFork(mainnetFork);
        // ideatokenhub create2 params
        address ideaTokenHubImpl = address(new IdeaTokenHub{salt: keccak256(bytes("IDEATOKENHUB"))}());
        bytes memory proxyCreationCode = type(ERC1967Proxy).creationCode;
        bytes memory constructorParams = abi.encode(address(ideaTokenHubImpl), '');
        bytes memory ideaTokenHubCreationCode = abi.encodePacked(proxyCreationCode, constructorParams);
        bytes32 ideaTokenHubHash = keccak256(ideaTokenHubCreationCode);
        console2.logBytes32(ideaTokenHubHash);

        bytes32 minedSalt = bytes32(uint256(0x3d1ee0b1bdc9bf3a9adfff25));
        address ideaTokenHubExpected = 0x000000000088b111eA8679dD42f7D55512fD6bE8;
        bytes memory creationCall = abi.encodeWithSignature("safeCreate2(bytes32,bytes)", minedSalt, ideaTokenHubCreationCode);
        (bool r, bytes memory ret) = 0x0000000000FFe8B47B3e2130213B802212439497.call(creationCall);
        require(r);
        address ideaTokenHubActual = abi.decode(ret, (address));
        console2.logAddress(ideaTokenHubActual);
    }

    function test_getWaveCoreHash() public {
        vm.selectFork(mainnetFork);

        // wave create2 params
        address ideaTokenHub = 0x000000000088b111eA8679dD42f7D55512fD6bE8;
        address nounsGovernorProxy = 0x6f3E6272A167e8AcCb32072d08E0957F9c79223d;
        address nounsToken = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;
        uint256 minSponsorshipAmount = 0.000777 ether;
        uint256 waveLength = 50400;
        address waveImpl = 0x62174FC3684ce4DFf3d75D2465E3b8ddb44534C2;
        address renderer = 0x65DBB4C59d4D5d279beec6dfdb169D986c55962C;
        address safe = 0x8c3aB329f3e5b43ee37ff3973b090F6A4a5Edf6c;

        bytes memory proxyCreationCode = type(ERC1967Proxy).creationCode;
        bytes memory initData = abi.encodeWithSelector(
            IWave.initialize.selector,
            ideaTokenHub,
            nounsGovernorProxy,
            nounsToken,
            minSponsorshipAmount,
            waveLength,
            renderer,
            safe
        );
        bytes memory waveConstructorParams = abi.encode(address(waveImpl), initData);
        bytes memory waveCreationCode = abi.encodePacked(proxyCreationCode, waveConstructorParams);
        bytes32 waveHash = keccak256(waveCreationCode);
        console2.logBytes32(waveHash);
    }

}
