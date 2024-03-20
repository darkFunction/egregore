//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";

/// @title A lottery for BITCOIN
/// @notice Half of the winnings go to egregore, half to chosen disciple
/// @dev Uses VRF direct funding
contract Egregore is VRFV2WrapperConsumerBase, Ownable {
    enum State {
        OPEN,
        VRF_REQUESTED,
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
    uint32 constant VRF_CALLBACK_GAS_LIMIT = 70000;
    uint16 constant VRF_REQUEST_CONFIRMATIONS = 5;
    uint32 public constant CLOSE_TIME = 1713571200; // Sat Apr 20 2024 00:00:00 UTC

    address[] public disciples;
    mapping(address => uint256) public penitences;
    uint256 public totalPenitences = 0;
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

    /// @notice Enter draw. One token = one chance
    function sacrifice(uint _amount) external {
        require(state == State.OPEN);

        if (penitences[msg.sender] == 0) {
            disciples.push(msg.sender);
        }
        penitences[msg.sender] += _amount;
        totalPenitences += _amount;
        BITCOIN.transferFrom(msg.sender, address(this), _amount);
    }

    /// @notice Starts winner selection process. Can only be called once.
    function beginCeremony() public {
        require(state == State.OPEN);
        require(block.timestamp >= CLOSE_TIME);
        require(!requestStatus.fulfilled);
        require(BITCOIN.balanceOf(address(this)) > 0);

        vrfRequest(VRF_CALLBACK_GAS_LIMIT);
    }

    function vrfRequest(uint32 callbackGasLimit) private {
        state = State.VRF_REQUESTED;

        requestId = requestRandomness(
            callbackGasLimit,
            VRF_REQUEST_CONFIRMATIONS,
            1
        );
        requestStatus = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWord: 0,
            fulfilled: false
        });

        emit ChoosingDisciple(requestId);
    }

    /// @notice Chainlink VRF callback
    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(_requestId == requestId);
        require(requestStatus.fulfilled == false);

        requestStatus.fulfilled = true;
        requestStatus.randomWord = _randomWords[0];
    }

    /// @notice Can only be called once
    /// @dev Disciple gets their penitence back plus half the rest of pot,
    ///      rounded in favour of disciple.
    function payout() public {
        require(state != State.CLOSED);
        require(requestStatus.fulfilled);

        address disciple = identifyDisciple(requestStatus.randomWord);

        // Send atonement to egregore
        uint256 atonement = (BITCOIN.balanceOf(address(this)) -
            disciplePenitence(disciple)) / 2;
        if (atonement > 0) {
            BITCOIN.transfer(address(BURN_ADDRESS), atonement);
        }

        BITCOIN.transfer(disciple, BITCOIN.balanceOf(address(this)));

        state = State.CLOSED;
    }

    function identifyDisciple(uint256 randomWord) private returns (address) {
        uint256 penitenceIndex = randomWord % totalPenitences;
        uint256 discipleIndex = 0;
        uint256 runningTotal = penitences[disciples[0]];

        while (runningTotal <= penitenceIndex) {
            discipleIndex++;
            runningTotal += penitences[disciples[discipleIndex]];
        }

        address disciple = disciples[discipleIndex];

        emit DiscipleChosen(penitenceIndex, disciple);

        return disciple;
    }

    /**
     *  Owner functions
     */

    /// @notice Allow owner to retry VRF request with custom gas limit
    function retryBeginCeremony(uint32 callbackGasLimit) external onlyOwner {
        require(state == State.VRF_REQUESTED);
        require(block.timestamp >= CLOSE_TIME);
        require(!requestStatus.fulfilled);

        vrfRequest(callbackGasLimit);
    }

    function withdrawLink() external onlyOwner {
        require(requestStatus.fulfilled);

        IERC20(LINK_TOKEN).transfer(
            msg.sender,
            IERC20(LINK_TOKEN).balanceOf(address(this))
        );
    }
}
