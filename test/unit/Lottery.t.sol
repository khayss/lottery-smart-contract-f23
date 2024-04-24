// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Lottery} from "../../src/Lottery.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract LotteryTest is Test {
    Lottery lottery;
    HelperConfig helperConfig;

    uint256 entryFee;
    uint256 lotteryDurationInSeconds;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 vrfCallbackGasLimit;
    address link;

    address public TEST_PARTICIPANT = makeAddr("participant");
    uint256 public constant TEST_PARTICIPANT_STARTING_BALANCE = 10 ether;

    /* Events */
    event EnteredLottery(address indexed participant);

    function setUp() external {
        deal(TEST_PARTICIPANT, TEST_PARTICIPANT_STARTING_BALANCE);

        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.run();

        (entryFee, lotteryDurationInSeconds, vrfCoordinator, gasLane, subscriptionId, vrfCallbackGasLimit, link,) =
            helperConfig.activeNetworkConfig();
    }

    function testLotteryStatusIsOpenOnInitialization() public view {
        assert(lottery.getLotteryStatus() == Lottery.LotteryStatus.OPEN);
    }

    function testRevertsWhenBelowEntryFeeSent() public {
        vm.prank(TEST_PARTICIPANT);

        vm.expectRevert(Lottery.Lottery__ValueSentBelowEntryFee.selector);
        lottery.joinLottery();
    }

    function testRecordsPlayerOnJoining() public {
        vm.prank(TEST_PARTICIPANT);

        lottery.joinLottery{value: entryFee}();

        assertEq(lottery.getParticipantAtIndex(0), TEST_PARTICIPANT);
    }

    function testEmitEventOnJoiningLottery() public {
        vm.prank(TEST_PARTICIPANT);

        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredLottery(TEST_PARTICIPANT);

        lottery.joinLottery{value: entryFee}();
    }

    function testRevertsWhenLotteryIsClosed() public {
        vm.prank(TEST_PARTICIPANT);

        lottery.joinLottery{value: entryFee}();
        vm.warp(block.timestamp + lotteryDurationInSeconds + 1);
        vm.roll(block.number + 1);

        lottery.performUpkeep("");

        vm.expectRevert(Lottery.Lottery__UpKeepNotNeeded.selector);
        vm.prank(TEST_PARTICIPANT);

        lottery.joinLottery{value: entryFee}();
    }
}
