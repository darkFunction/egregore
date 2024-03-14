//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract Egregore is VRFConsumerBaseV2 {
    IERC20 public constant BITCOIN =
        IERC20(0x72e4f9F808C49A2a61dE9C5896298920Dc4EEEa9);

    address[] public disciples;
    mapping(address => uint256) public penitences;
    uint64 s_subscriptionId;
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;

    enum AltarState {
        DARKNESS_APPROACHES,
        REDEMPTION,
        END_TIMES
    }

    event DiscipleChosen(uint256 penitenceIndex, address fleshHost);

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
    }

    function sacrifice(uint _amount) external {
        if (penitences[msg.sender] == 0) {
            disciples.push(msg.sender);
        }
        penitences[msg.sender] += _amount;
        BITCOIN.transferFrom(msg.sender, address(this), _amount);
    }

    function consumeMyFlesh() private {
        // Send atonement to egregore
        BITCOIN.transferFrom(
            address(this),
            address(666),
            BITCOIN.balanceOf(address(this)) / 2
        );
        BITCOIN.transferFrom(
            address(this),
            curseTheDisciple(),
            BITCOIN.balanceOf(address(this))
        );
    }

    function curseTheDisciple() private returns (address) {}

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // transform the result to a number between 1 and 20 inclusively
        // uint256 d20Value = (randomWords[0] % 20) + 1;
        // // assign the transformed value to the address in the s_results mapping variable
        // s_results[s_rollers[requestId]] = d20Value;
        // // emitting event to signal that dice landed
        // emit DiceLanded(requestId, d20Value);
    }
}
