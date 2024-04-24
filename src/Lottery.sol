// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Lottery is VRFConsumerBaseV2 {
    /**
     * errors
     */
    error Lottery__ValueSentBelowEntryFee();
    error Lottery__ContributionDurationOver();
    error Lottery__UpKeepNotNeeded(uint256 lotteryBalance, uint256 numParticipants, uint256 status);
    error Lottery__FundsNotSentToWinner();
    error Lottery__NotOpen();

    /**
     * Types
     */
    enum LotteryStatus {
        OPEN,
        CLOSED,
        PROCESSING
    }

    /**
     * state variables
     */
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;

    uint32 private immutable i_vrfCallbackGasLimit;
    uint64 private immutable i_subscriptionId;
    uint256 private immutable i_entryFee;
    uint256 private immutable i_lotteryDurationInSeconds;
    uint256 private immutable i_lotteryStartTime;

    bytes32 private immutable i_gasLane;

    address private s_lotteryWinner;

    LotteryStatus private s_lotteryStatus;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    address payable[] private s_participants;

    /**
     * events
     */
    event EnteredLottery(address indexed participant);
    event PickedWinner(address indexed participant);
    /**
     * modifiers
     */
    /**
     * functions
     */

    constructor(
        uint256 _entryFee,
        uint256 _lotteryDurationInSeconds,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _vrfCallbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_entryFee = _entryFee;
        i_lotteryDurationInSeconds = _lotteryDurationInSeconds;
        i_lotteryStartTime = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_vrfCallbackGasLimit = _vrfCallbackGasLimit;
        s_lotteryStatus = LotteryStatus.OPEN;
    }

    function joinLottery() external payable {
        if ((block.timestamp - i_lotteryStartTime) > i_lotteryDurationInSeconds) {
            revert Lottery__ContributionDurationOver();
        }
        if (s_lotteryStatus != LotteryStatus.OPEN) {
            revert Lottery__NotOpen();
        }
        if (msg.value < i_entryFee) {
            revert Lottery__ValueSentBelowEntryFee();
        }

        address newParticipant = msg.sender;
        s_participants.push(payable(newParticipant));

        emit EnteredLottery(newParticipant);
    }

    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool lotteryDurationEnded = ((block.timestamp - i_lotteryStartTime) > i_lotteryDurationInSeconds);
        bool hasBalanceGreaterThanZero = address(this).balance > 0;
        bool hasParticipants = s_participants.length > 0;
        bool isOpen = LotteryStatus.OPEN == s_lotteryStatus;

        upkeepNeeded = (lotteryDurationEnded && hasBalanceGreaterThanZero && hasParticipants && isOpen);
        return (upkeepNeeded, "0x0");
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    function performUpkeep(bytes calldata /* performData */ ) public {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpKeepNotNeeded(address(this).balance, s_participants.length, uint256(s_lotteryStatus));
        }

        s_lotteryStatus = LotteryStatus.PROCESSING;

        i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATION, i_vrfCallbackGasLimit, NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256,
        /**
         * _requestId
         */
        uint256[] memory _randomWords
    ) internal override {
        uint256 randomIndex = _randomWords[0] % s_participants.length;
        address payable winner = s_participants[randomIndex];
        s_lotteryWinner = winner;

        s_lotteryStatus = LotteryStatus.CLOSED;

        emit PickedWinner(winner);

        (bool success,) = winner.call{value: address(this).balance}("");

        if (!success) {
            revert Lottery__FundsNotSentToWinner();
        }
    }

    /* Getter functions */

    function getLotteryStatus() external view returns (LotteryStatus) {
        return s_lotteryStatus;
    }

    function getParticipantAtIndex(uint256 _participantIndex) public view returns (address) {
        address participant = s_participants[_participantIndex];
        return participant;
    }
}
