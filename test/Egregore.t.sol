// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Egregore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EgregoreTest is Test {
    Egregore egregore;
    address constant HOLDER = 0xA4644953Ad98ED5A7ff106ED9a3909C9AEbcBC31;
    address constant HOLDER2 = 0xbCb00ef3938FD826F8CF3D4E75314f39bb8846C1;
    address constant LINK_MARINE = 0xd072A5d8F322dD59dB173603fBb6CBb61F3F3D28;
    IERC20 constant LINK_TOKEN =
        IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    IERC20 constant BITCOIN =
        IERC20(0x72e4f9F808C49A2a61dE9C5896298920Dc4EEEa9);
    address constant VRF_WRAPPER = 0x5A861794B927983406fCE1D062e00b9368d97Df6;
    address constant BURN_ADDRESS = 0x0000000000000000000000000000000000000666;

    function setUp() public {
        egregore = new Egregore();

        vm.createSelectFork(vm.envString("RPC_MAINNET"), 19435843);
    }

    function test_whenEgregoreInitialised_thenStateIsOpen() public view {
        assertEq(uint(egregore.state()), uint(Egregore.State.OPEN));
    }

    function test_whenSacrifice_thenAddsDisciple_andAddsPenitenceToDisciple()
        public
    {
        vm.warp(egregore.CLOSE_TIME() - 1);

        vm.startPrank(HOLDER);
        BITCOIN.approve(address(egregore), BITCOIN.balanceOf(HOLDER));
        assertEq(BITCOIN.balanceOf(address(egregore)), 0);
        assertEq(egregore.disciplePenitence(HOLDER), 0);
        assertEq(egregore.disciplePenitence(HOLDER2), 0);
        egregore.sacrifice(100);
        assertEq(egregore.discipleCount(), 1);
        assertEq(BITCOIN.balanceOf(address(egregore)), 100);
        assertEq(egregore.disciplePenitence(HOLDER), 100);
        egregore.sacrifice(100);
        assertEq(egregore.discipleCount(), 1);
        assertEq(BITCOIN.balanceOf(address(egregore)), 200);
        assertEq(egregore.disciplePenitence(HOLDER), 200);
        vm.stopPrank();

        vm.startPrank(HOLDER2);
        BITCOIN.approve(address(egregore), BITCOIN.balanceOf(HOLDER2));
        egregore.sacrifice(100);
        assertEq(egregore.discipleCount(), 2);
        assertEq(BITCOIN.balanceOf(address(egregore)), 300);
        assertEq(egregore.disciplePenitence(HOLDER2), 100);
        egregore.sacrifice(100);
        assertEq(egregore.discipleCount(), 2);
        assertEq(BITCOIN.balanceOf(address(egregore)), 400);
        assertEq(egregore.disciplePenitence(HOLDER2), 200);
        vm.stopPrank();
    }

    function test_givenAfterClosingDate_whenBeginCeremonyAndHasLinkBalance_thenSucceeds()
        public
    {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        enterHolder(HOLDER, 1);
        egregore.beginCeremony();
    }

    function test_whenBeginCeremonyCalledMultipleTimes_thenReverts() public {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        enterHolder(HOLDER, 1);
        egregore.beginCeremony();
        vm.expectRevert();
        egregore.beginCeremony();
    }

    function test_givenContractHasChainlink_andCeremonyStarted_whenVRFCallbackOccurs_thenSetsRequestStatus()
        public
    {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        enterHolder(HOLDER, 1);
        egregore.beginCeremony();
        fulfillRandom(10);

        (, bool fulfilled, ) = egregore.requestStatus();
        assertEq(fulfilled, true);
    }

    function test_givenContractHasLink_whenCeremonyStarted_thenStatusIsVRFRequestedAndRequestIdNotZero()
        public
    {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        enterHolder(HOLDER, 1);
        egregore.beginCeremony();
        assertNotEq(egregore.requestId(), 0);
        assertEq(uint(egregore.state()), uint(Egregore.State.VRF_REQUESTED));
    }

    function test_givenContractHasChainlink_andCeremonyNotStarted_whenVRFCallbackOccurs_thenReverts()
        public
    {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 10;
        vm.prank(VRF_WRAPPER);
        uint requestId = egregore.requestId();
        vm.expectRevert();
        egregore.rawFulfillRandomWords(requestId, randomWords);
    }

    function test_whenPayoutCalled_thenSplitsBitcoinBetweenVoidAndWinner_andEmitsEvent()
        public
    {
        vm.warp(0);
        uint holderBalance = enterHolder(HOLDER, 100);
        enterHolder(HOLDER2, 500);

        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        fulfillRandom(0);

        egregore.payout();

        assertEq(
            BITCOIN.balanceOf(
                address(0x0000000000000000000000000000000000000666)
            ),
            300
        );
        assertEq(BITCOIN.balanceOf(HOLDER), holderBalance + 200);
    }

    function test_whenPayoutCalled_thenChoosesCorrectWinner() public {
        vm.warp(0);

        uint256 holderBalance = enterHolder(HOLDER, 100);
        uint256 holder2Balance = enterHolder(HOLDER2, 500);

        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        fulfillRandom(100);
        egregore.payout();

        assertEq(BITCOIN.balanceOf(HOLDER), holderBalance - 100);
        assertEq(BITCOIN.balanceOf(HOLDER2), holder2Balance - 200);
    }

    function test_happyPath() public {
        vm.warp(0);
        fundContractWithLink();

        enterHolder(HOLDER, 1);
        uint holder2Balance = enterHolder(HOLDER2, 2);

        vm.warp(egregore.CLOSE_TIME());
        egregore.beginCeremony();

        fulfillRandom(1);
        egregore.payout();

        assertEq(BITCOIN.balanceOf(HOLDER2), holder2Balance);
        assertEq(BITCOIN.balanceOf(BURN_ADDRESS), 1);

        egregore.withdrawLink();
    }

    function test_failOnEarlyPayout() public {
        vm.warp(0);
        fundContractWithLink();

        enterHolder(HOLDER, 1);
        enterHolder(HOLDER2, 2);

        vm.warp(egregore.CLOSE_TIME());
        egregore.beginCeremony();

        vm.expectRevert();
        egregore.payout();
    }

    function test_retryBeginCeremonyFails_ifBeginCeremonyNotCalled() public {
        fundContractWithLink();
        enterHolder(HOLDER, 1);
        vm.warp(egregore.CLOSE_TIME());
        vm.expectRevert();
        egregore.retryBeginCeremony(100000);
    }

    function test_retryBeginCeremonySucceeds_ifBeginCeremonyFails() public {
        fundContractWithLink();
        enterHolder(HOLDER, 1);
        vm.warp(egregore.CLOSE_TIME());
        egregore.beginCeremony();
        egregore.retryBeginCeremony(100000);
    }

    function test_retryBeginCeremonyFails_ifBeginCeremonySucceeds() public {
        fundContractWithLink();
        enterHolder(HOLDER, 1);
        vm.warp(egregore.CLOSE_TIME());
        egregore.beginCeremony();
        fulfillRandom(100);
        vm.expectRevert();
        egregore.retryBeginCeremony(100000);
    }

    /**
     *  HELPER FUNCTIONS
     */

    function fulfillRandom(uint256 number) private {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = number;
        vm.startPrank(VRF_WRAPPER);
        egregore.rawFulfillRandomWords(egregore.requestId(), randomWords);
        vm.stopPrank();
    }

    function enterHolder(
        address holder,
        uint256 amount
    ) private returns (uint256) {
        uint256 preBalance = BITCOIN.balanceOf(holder);

        vm.startPrank(holder);
        BITCOIN.approve(address(egregore), BITCOIN.balanceOf(holder));
        egregore.sacrifice(amount);
        vm.stopPrank();

        return preBalance;
    }

    function fundContractWithLink() private {
        vm.startPrank(LINK_MARINE);
        LINK_TOKEN.transfer(
            address(egregore),
            LINK_TOKEN.balanceOf(LINK_MARINE)
        );
        vm.stopPrank();
    }
}
