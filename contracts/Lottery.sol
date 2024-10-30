// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Lottery is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    address public owner;
    uint public lottery_id;
    uint public lottery_duration;

    struct ParticipantInfo {
        address participant_address;
        uint bid_amount;
        uint bid_time;
    }

    struct winnerDetails {
        address winnerAddress;
        uint winnerBidAmount;
        uint winnerBidTime;
        uint winningPercentage;
        uint winningAmount;
    }

    struct lotteryInfo {
        uint startTime;
        uint endTime;
        bool isCompleted;
    }

    mapping(uint => ParticipantInfo[]) public participants_details;
    mapping(uint => mapping(address => uint)) public participant_index;
    mapping(uint => winnerDetails[]) public winner_details;
    mapping(uint => lotteryInfo) public lotteries;

    /**
     * @dev Event to emit participant information
     */
    event participantInfo(
        uint lottery_id,
        uint lottery_start_time,
        uint lottery_end_time,
        address wallet_address,
        uint bid_amount,
        uint bid_time
    );

    /**
     * @dev Modifier to restrict access to the contract owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the Owner");
        _;
    }

    /**
     * @dev Constructor to disable initializers
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialization function
     * @param _admin The address of the contract owner
     */
    function initialize(address _admin) external initializer {
        owner = _admin;
        lottery_duration = 120;
        __ReentrancyGuard_init();
    }

    /**
     * @dev Function to add participants to the lottery
     * @notice This function is non-reentrant
     */
    function addParticipants() external payable nonReentrant {
        require(msg.value > 0 ether, "Amount should be greater than 0 Bdag");
        uint index = participant_index[lottery_id][msg.sender];

        if (
            index != 0 ||
            (participants_details[lottery_id].length > 0 &&
                participants_details[lottery_id][0].participant_address ==
                msg.sender)
        ) {
            participants_details[lottery_id][index].bid_amount += msg.value;
            participants_details[lottery_id][index].bid_time = block.timestamp;
        } else {
            participants_details[lottery_id].push(
                ParticipantInfo({
                    participant_address: msg.sender,
                    bid_amount: msg.value,
                    bid_time: block.timestamp
                })
            );

            participant_index[lottery_id][msg.sender] =
                participants_details[lottery_id].length -
                1;

            if (participants_details[lottery_id].length == 1) {
                lotteries[lottery_id].startTime = block.timestamp;
                lotteries[lottery_id].endTime =
                    block.timestamp +
                    lottery_duration;
            }
        }

        emit participantInfo(
            lottery_id,
            lotteries[lottery_id].startTime,
            lotteries[lottery_id].endTime,
            msg.sender,
            msg.value,
            block.timestamp
        );
    }

    /**
     * @dev Internal function to generate a random reward value
     * @param rewards_given The number of rewards given so far
     * @return The randomly generated reward value
     */
    function reward(uint rewards_given) internal view returns (uint) {
        uint range = 10;
        uint a = uint(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    rewards_given,
                    msg.sender
                )
            )
        ) % range;
        return a;
    }

    /**
     * @dev Function to determine the lottery winner
     * @notice This function can only be called by the contract owner
     */
    function lotteryWinner() external onlyOwner {
        require(
            block.timestamp >= lotteries[lottery_id].endTime,
            "Lottery is under process"
        );
        require(
            participants_details[lottery_id].length != 0,
            "No participants registered"
        );

        ParticipantInfo[] memory participants = participants_details[
            lottery_id
        ];
        uint numParticipants = participants.length;

        uint[] memory rewards = new uint[](numParticipants);

        for (uint i = 0; i < numParticipants; i++) {
            uint rewardValue = reward(i);
            rewards[i] = (rewardValue != 0) ? rewardValue : (rewardValue + 1);

            uint winningAmount = participants[i].bid_amount * rewards[i];

            winner_details[lottery_id].push(
                winnerDetails({
                    winnerAddress: participants[i].participant_address,
                    winnerBidAmount: participants[i].bid_amount,
                    winnerBidTime: participants[i].bid_time,
                    winningPercentage: rewards[i],
                    winningAmount: winningAmount
                })
            );

            (bool successful, ) = participants[i].participant_address.call{
                value: winningAmount
            }("");
            require(successful, "Payment failed.");
        }

        lotteries[lottery_id].isCompleted = true;
        lottery_id++;
    }

    /**
     * @dev Function to rescue the contract's balance
     * @notice This function can only be called by the contract owner
     */
    function rescue() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    /**
     * @dev Function to change the lottery duration
     * @param duration The new lottery duration in seconds
     * @notice This function can only be called by the contract owner
     */
    function change_lottery_duration(uint duration) external onlyOwner {
        lottery_duration = duration;
    }

    /**
     * @dev Function to get participant details
     * @param lotteryId The ID of the lottery
     * @param participantAddress The address of the participant
     * @return The participant's details
     */
    function getParticipantDetails(
        uint lotteryId,
        address participantAddress
    ) external view returns (ParticipantInfo memory) {
        uint index = participant_index[lotteryId][participantAddress];
        require(
            index < participants_details[lotteryId].length,
            "Participant does not exist"
        );
        return participants_details[lotteryId][index];
    }

    /**
     * @dev Function to get all participants for a lottery
     * @param lotteryId The ID of the lottery
     * @return An array of all participants
     */
    function getAllParticipants(
        uint lotteryId
    ) external view returns (ParticipantInfo[] memory) {
        return participants_details[lotteryId];
    }

    /**
     * @dev Function to get the winner details for a lottery
     * @param lotteryId The ID of the lottery
     * @return An array of winner details
     */
    function WinnerDetails(
        uint lotteryId
    ) external view returns (winnerDetails[] memory) {
        return winner_details[lotteryId];
    }

    /**
     * @dev Function to get the lottery information
     * @param lotteryId The ID of the lottery
     * @return The lottery information
     */
    function readLotteryInfo(
        uint lotteryId
    ) external view returns (lotteryInfo memory) {
        return lotteries[lotteryId];
    }

    /**
     * @dev Function to get the end time of the current lottery
     * @return The end time of the current lottery
     */
    function current_lottery_end_time() external view returns (uint) {
        return lotteries[lottery_id].endTime;
    }

    /**
     * @dev Function to get the start time of the current lottery
     * @return The start time of the current lottery
     */
    function current_lottery_start_time() external view returns (uint) {
        return lotteries[lottery_id].startTime;
    }

    /**
     * @dev Function to get the current lottery ID
     * @return The current lottery ID
     */
    function readLotteryId() external view returns (uint) {
        return lottery_id;
    }

    /**
     * @dev Authorize the contract upgrade
     * @param newImplementation The address of the new contract implementation
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @dev Fallback and receive functions
     */
    receive() external payable {}

    fallback() external payable {}
}
