// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract Reflection is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    address public owner;

    event reflect_info (
        uint amount
    );

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
        __ReentrancyGuard_init();
    }

    /**
     * @dev Modifier to restrict access to the contract owner
    */

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the Owner");
        _;
    }

    /**
     * @dev Function to add participants to the lottery
     * @notice This function is non-reentrant
    */

    function reflect() external payable nonReentrant {
        
        (bool successful, ) = msg.sender.call{value: msg.value }("");
        require(
            successful, "Payment failed."
        );
        emit reflect_info(msg.value);
    }

    function _authorizeUpgrade(address newImplementation)
            internal
            onlyOwner()
            override
        {}

    receive() external payable {}
    fallback() external payable {}
}