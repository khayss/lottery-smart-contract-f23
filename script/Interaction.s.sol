// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscription(address _vrfCoordinator, uint256 _deployKey) public returns (uint64) {
        vm.startBroadcast(_deployKey);

        VRFCoordinatorV2Mock vrfCoordinatorMock = VRFCoordinatorV2Mock(_vrfCoordinator);
        uint64 subscriptionId = vrfCoordinatorMock.createSubscription();
        vm.stopBroadcast();

        return subscriptionId;
    }

    function createSubscriptionFromConfig() public returns (uint64) {
        HelperConfig config = new HelperConfig();
        (,, address vrfCoordinator,,,,, uint256 deployKey) = config.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployKey);
    }

    function run() external returns (uint64) {
        return createSubscriptionFromConfig();
    }
}

contract FundSubscription is Script {
    uint96 private constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig config = new HelperConfig();
        (,, address vrfCoordinator,, uint64 subId,, address link, uint256 deployKey) = config.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, deployKey);
    }

    function fundSubscription(address _vrfCoordinator, uint64 _subId, address _link, uint256 _deployKey) public {
        if (block.chainid == 31337) {
            vm.startBroadcast(_deployKey);
            VRFCoordinatorV2Mock(_vrfCoordinator).fundSubscription(_subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(_deployKey);
            LinkToken(_link).transferAndCall(_vrfCoordinator, FUND_AMOUNT, abi.encode(_subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address _lottery) public {
        HelperConfig config = new HelperConfig();
        (,, address vrfCoordinator,, uint64 subId,,, uint256 deployKey) = config.activeNetworkConfig();
        addConsumer(vrfCoordinator, subId, _lottery, deployKey);
    }

    function addConsumer(address _vrfCoordinator, uint64 _subId, address _lottery, uint256 _deployKey) public {
        vm.startBroadcast(_deployKey);
        VRFCoordinatorV2Mock(_vrfCoordinator).addConsumer(_subId, _lottery);
        vm.stopBroadcast();
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment("Lottery", block.chainid);

        addConsumerUsingConfig(lottery);
    }
}
