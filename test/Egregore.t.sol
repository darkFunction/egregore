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
        vm.startPrank(HOLDER);
        vm.warp(egregore.CLOSE_TIME() - 1);

        // Approve Egregore to spend holder's BITCOIN
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
        egregore.beginCeremony();
    }

    function test_whenBeginCeremonyCalledMultipleTimes_thenReverts() public {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        vm.expectRevert();
        egregore.beginCeremony();
    }

    function test_givenContractHasChainlink_andCeremonyStarted_whenVRFCallbackOccurs_thenSetsRequestStatus()
        public
    {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 10;
        uint requestId = egregore.requestId();
        vm.prank(VRF_WRAPPER);
        egregore.rawFulfillRandomWords(requestId, randomWords);

        (, bool fulfilled, ) = egregore.requestStatus();
        assertEq(fulfilled, true);
    }

    function test_givenContractHasLink_whenCeremonyStarted_thenStatusIsChoosingAndRequestIdNotZero()
        public
    {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        assertNotEq(egregore.requestId(), 0);
        assertEq(uint(egregore.state()), uint(Egregore.State.CHOOSING));
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
        vm.startPrank(HOLDER);
        BITCOIN.approve(address(egregore), BITCOIN.balanceOf(HOLDER));
        egregore.sacrifice(100);
        uint holderBalance = BITCOIN.balanceOf(HOLDER);
        vm.stopPrank();

        vm.startPrank(HOLDER2);
        BITCOIN.approve(address(egregore), BITCOIN.balanceOf(HOLDER2));
        egregore.sacrifice(500);
        vm.stopPrank();

        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;
        vm.startPrank(VRF_WRAPPER);
        egregore.rawFulfillRandomWords(egregore.requestId(), randomWords);
        vm.stopPrank();

        egregore.payout();

        assertEq(
            BITCOIN.balanceOf(
                address(0x0000000000000000000000000000000000000666)
            ),
            300
        );
        assertEq(BITCOIN.balanceOf(HOLDER), holderBalance + 300);
    }

    function test_whenPayoutCalled_thenChoosesCorrectWinner() public {
        vm.warp(0);
        vm.startPrank(HOLDER);
        BITCOIN.approve(address(egregore), BITCOIN.balanceOf(HOLDER));
        egregore.sacrifice(100);
        uint holderBalance = BITCOIN.balanceOf(HOLDER);
        vm.stopPrank();

        vm.startPrank(HOLDER2);
        BITCOIN.approve(address(egregore), BITCOIN.balanceOf(HOLDER2));
        egregore.sacrifice(500);
        uint holder2Balance = BITCOIN.balanceOf(HOLDER2);
        vm.stopPrank();

        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 100;
        vm.startPrank(VRF_WRAPPER);
        egregore.rawFulfillRandomWords(egregore.requestId(), randomWords);
        vm.stopPrank();

        egregore.payout();

        assertEq(BITCOIN.balanceOf(HOLDER), holderBalance);
        assertEq(BITCOIN.balanceOf(HOLDER2), holder2Balance + 300);
    }

    function fundContractWithLink() private {
        vm.startPrank(LINK_MARINE);
        LINK_TOKEN.approve(LINK_MARINE, LINK_TOKEN.balanceOf(LINK_MARINE));
        LINK_TOKEN.transferFrom(
            LINK_MARINE,
            address(egregore),
            LINK_TOKEN.balanceOf(LINK_MARINE)
        );
        vm.stopPrank();
    }
}
