// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";

contract DeployLottery is Script {
    function run() external returns (Lottery, HelperConfig) {
        HelperConfig config = new HelperConfig();
        AddConsumer addConsumer = new AddConsumer();
        (
            uint256 entryFee,
            uint256 lotteryDurationInSeconds,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 vrfCallbackGasLimit,
            address link,
            uint256 deployKey
        ) = config.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployKey);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, deployKey);
        }

        vm.startBroadcast(deployKey);

        Lottery lottery = new Lottery(
            entryFee, lotteryDurationInSeconds, vrfCoordinator, gasLane, subscriptionId, vrfCallbackGasLimit
        );

        vm.stopBroadcast();

        addConsumer.addConsumer(vrfCoordinator, subscriptionId, address(lottery), deployKey);

        return (lottery, config);
    }
}
