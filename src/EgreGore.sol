//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

contract EgreGore is VRFConsumerBaseV2 {
    IERC20 public constant BITCOIN =
        IERC20(0x72e4f9F808C49A2a61dE9C5896298920Dc4EEEa9);

    address[] public disciples;
    mapping(address => uint256) public penitences;

    enum AltarState {
        DARKNESS_APPROACHES,
        REDEMPTION,
        END_TIMES
    }

    event DiscipleChosen(uint256 penitenceIndex, address fleshHost);

    constructor() {}

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
}
