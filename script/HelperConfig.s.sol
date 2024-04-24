// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entryFee;
        uint256 lotteryDurationInSeconds;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 vrfCallbackGasLimit;
        address link;
        uint256 deployKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryFee: 0.1 ether,
            lotteryDurationInSeconds: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 11216,
            vrfCallbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployKey: 0
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        uint256 ANVIL_DEPLOY_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        uint96 baseFee = 0.25 ether; // 0.25 LINK
        uint96 gasPriceLink = 1e9; // 1 gwei LINK
        vm.startBroadcast();
        VRFCoordinatorV2Mock mockVrfCoordinator = new VRFCoordinatorV2Mock(baseFee, gasPriceLink);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        return NetworkConfig({
            entryFee: 0.1 ether,
            lotteryDurationInSeconds: 30,
            vrfCoordinator: address(mockVrfCoordinator),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0,
            vrfCallbackGasLimit: 500000,
            link: address(linkToken),
            deployKey: ANVIL_DEPLOY_KEY
        });
    }
}
