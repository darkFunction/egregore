//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";

contract Egregore is VRFV2WrapperConsumerBase, Ownable {
    enum State {
        OPEN,
        CHOOSING,
        CLOSED
    }

    event ChoosingDisciple(uint256 requestId);
    event DiscipleChosen(uint256 penitenceIndex, address fleshHost);

    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256 randomWord;
    }

    address constant LINK_TOKEN = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address constant VRF_WRAPPER = 0x5A861794B927983406fCE1D062e00b9368d97Df6;
    address constant BURN_ADDRESS = 0x0000000000000000000000000000000000000666;
    IERC20 constant BITCOIN =
        IERC20(0x72e4f9F808C49A2a61dE9C5896298920Dc4EEEa9);
    uint32 constant VRF_CALLBACK_GAS_LIMIT = 41364;
    uint16 constant VRF_REQUEST_CONFIRMATIONS = 5;

    address[] public disciples;
    mapping(address => uint256) public penitences;
    uint public totalPenitences = 0;

    // Sat Apr 20 2024 00:00:00 GMT+0000
    uint public constant CLOSE_TIME = 1713571200;
    uint256 public requestId;
    RequestStatus public requestStatus;

    State public state;

    constructor()
        VRFV2WrapperConsumerBase(LINK_TOKEN, VRF_WRAPPER)
        Ownable(msg.sender)
    {}

    function discipleCount() public view returns (uint) {
        return disciples.length;
    }

    function disciplePenitence(address _disciple) public view returns (uint) {
        return penitences[_disciple];
    }

    function sacrifice(uint _amount) external {
        require(state == State.OPEN);

        if (penitences[msg.sender] == 0) {
            disciples.push(msg.sender);
        }
        penitences[msg.sender] += _amount;
        totalPenitences += _amount;
        BITCOIN.transferFrom(msg.sender, address(this), _amount);
    }

    function beginCeremony() public {
        require(state == State.OPEN);
        require(block.timestamp >= CLOSE_TIME);
        state = State.CHOOSING;

        requestId = requestRandomness(
            VRF_CALLBACK_GAS_LIMIT,
            VRF_REQUEST_CONFIRMATIONS,
            1
        );
        requestStatus = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(VRF_CALLBACK_GAS_LIMIT),
            randomWord: 0,
            fulfilled: false
        });

        emit ChoosingDisciple(requestId);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(_requestId == requestId);
        require(state == State.CHOOSING);
        require(requestStatus.fulfilled == false);

        requestStatus.fulfilled = true;
        requestStatus.randomWord = _randomWords[0];
    }

    function payout() public {
        require(state == State.CHOOSING);
        require(requestStatus.fulfilled == true);

        state = State.CLOSED;

        uint penitenceIndex = requestStatus.randomWord % totalPenitences;
        uint discipleIndex = 0;
        uint runningTotal = penitences[disciples[0]];

        while (runningTotal <= penitenceIndex) {
            discipleIndex++;
            runningTotal += penitences[disciples[discipleIndex]];
        }

        address disciple = disciples[discipleIndex];

        BITCOIN.approve(address(this), BITCOIN.balanceOf(address(this)));

        // Send atonement to egregore
        BITCOIN.transferFrom(
            address(this),
            address(BURN_ADDRESS),
            BITCOIN.balanceOf(address(this)) / 2
        );

        BITCOIN.transferFrom(
            address(this),
            disciple,
            BITCOIN.balanceOf(address(this))
        );

        emit DiscipleChosen(penitenceIndex, disciple);
    }

    function withdrawLink() external onlyOwner {
        IERC20(LINK_TOKEN).transfer(
            msg.sender,
            IERC20(LINK_TOKEN).balanceOf(address(this))
        );
    }
}
