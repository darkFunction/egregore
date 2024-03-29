// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Egregore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract EgregoreTest is Test {
    Egregore egregore;
    address constant BITCOIN_UNISWAP_LP =
        0x2cC846fFf0b08FB3bFfaD71f53a60B4b6E6d6482;
    address constant LINK_MARINE = 0xd072A5d8F322dD59dB173603fBb6CBb61F3F3D28;
    IERC20 constant LINK_TOKEN =
        IERC20(0x514910771AF9Ca656af840dff83E8264EcF986CA);
    IERC20 constant BITCOIN =
        IERC20(0x72e4f9F808C49A2a61dE9C5896298920Dc4EEEa9);
    address constant VRF_WRAPPER = 0x5A861794B927983406fCE1D062e00b9368d97Df6;
    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address constant BITCOIN_UNISWAP_POOL =
        0x2cC846fFf0b08FB3bFfaD71f53a60B4b6E6d6482;

    function setUp() public {
        egregore = new Egregore();

        vm.createSelectFork(vm.envString("RPC_MAINNET"), 19435843);
        uint256 existingBurnAddressBalance = BITCOIN.balanceOf(BURN_ADDRESS);
        vm.prank(BURN_ADDRESS);
        BITCOIN.transfer(address(1), existingBurnAddressBalance);
    }

    function test_whenEgregoreInitialised_thenStateIsOpen() public view {
        assertEq(uint(egregore.state()), uint(Egregore.State.OPEN));
    }

    function test_whenSacrifice_thenAddsDisciple_andAddsPenitenceToDisciple()
        public
    {
        vm.warp(egregore.CLOSE_TIME() - 1);

        assertEq(BITCOIN.balanceOf(address(egregore)), 0);
        assertEq(egregore.disciplePenitence(address(101)), 0);
        assertEq(egregore.disciplePenitence(address(102)), 0);

        enterHolder(address(101), 100);
        assertEq(egregore.entryCount(), 1);
        assertEq(BITCOIN.balanceOf(address(egregore)), 100);
        assertEq(egregore.disciplePenitence(address(101)), 100);

        enterHolder(address(101), 100);
        assertEq(egregore.entryCount(), 2);
        assertEq(BITCOIN.balanceOf(address(egregore)), 200);
        assertEq(egregore.disciplePenitence(address(101)), 200);

        enterHolder(address(102), 100);
        assertEq(egregore.entryCount(), 3);
        assertEq(BITCOIN.balanceOf(address(egregore)), 300);
        assertEq(egregore.disciplePenitence(address(102)), 100);

        enterHolder(address(102), 100);
        assertEq(egregore.entryCount(), 4);
        assertEq(BITCOIN.balanceOf(address(egregore)), 400);
        assertEq(egregore.disciplePenitence(address(102)), 200);
    }

    function test_givenAfterClosingDate_whenBeginCeremonyAndHasLinkBalance_thenSucceeds()
        public
    {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        enterHolder(address(101), 1);
        egregore.beginCeremony();
    }

    function test_whenBeginCeremonyCalledMultipleTimes_thenReverts() public {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        enterHolder(address(101), 1);
        egregore.beginCeremony();
        vm.expectRevert();
        egregore.beginCeremony();
    }

    function test_givenContractHasChainlink_andCeremonyStarted_whenVRFCallbackOccurs_thenSetsRequestStatus()
        public
    {
        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        enterHolder(address(101), 1);
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
        enterHolder(address(101), 1);
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
        enterHolder(address(101), 100);
        enterHolder(address(102), 500);

        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        fulfillRandom(0);

        egregore.payout();

        assertEq(BITCOIN.balanceOf(address(BURN_ADDRESS)), 250);
        assertEq(BITCOIN.balanceOf(address(101)), 350);
    }

    function test_whenPayoutCalled_thenChoosesCorrectWinner2() public {
        vm.warp(0);

        enterHolder(address(101), 100);
        enterHolder(address(102), 500);
        enterHolder(address(103), 10000);

        assertEq(BITCOIN.balanceOf(address(egregore)), 10600);
        assertEq(egregore.totalPenitences(), 10600);

        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        fulfillRandom(100);
        egregore.payout();

        assertEq(BITCOIN.balanceOf(address(101)), 0);
        assertEq(BITCOIN.balanceOf(address(102)), 5550);
        assertEq(BITCOIN.balanceOf(address(103)), 0);
        assertEq(BITCOIN.balanceOf(BURN_ADDRESS), 5050);
    }

    function test_whenPayoutCalled_thenChoosesCorrectWinner4() public {
        vm.warp(0);

        enterHolder(address(101), 100);
        enterHolder(address(101), 500);
        enterHolder(address(102), 10000);
        enterHolder(address(103), 1);
        enterHolder(address(104), 1);

        assertEq(BITCOIN.balanceOf(address(egregore)), 10602);
        assertEq(egregore.totalPenitences(), 10602);

        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        fulfillRandom(10601);
        egregore.payout();

        assertEq(BITCOIN.balanceOf(address(101)), 0);
        assertEq(BITCOIN.balanceOf(address(102)), 0);
        assertEq(BITCOIN.balanceOf(address(103)), 0);
        assertEq(BITCOIN.balanceOf(address(104)), 5302);
        assertEq(BITCOIN.balanceOf(BURN_ADDRESS), 5300);
    }

    function test_whenPayoutCalled_thenChoosesCorrectWinner2b() public {
        vm.warp(0);

        enterHolder(address(101), 100);
        enterHolder(address(101), 500);
        enterHolder(address(102), 10000);
        enterHolder(address(103), 1);
        enterHolder(address(104), 1);

        assertEq(BITCOIN.balanceOf(address(egregore)), 10602);
        assertEq(egregore.totalPenitences(), 10602);

        vm.warp(egregore.CLOSE_TIME());
        fundContractWithLink();
        egregore.beginCeremony();
        fulfillRandom(600);
        egregore.payout();

        assertEq(BITCOIN.balanceOf(address(101)), 0);
        assertEq(BITCOIN.balanceOf(address(102)), 10301);
        assertEq(BITCOIN.balanceOf(address(103)), 0);
        assertEq(BITCOIN.balanceOf(address(104)), 0);
        assertEq(BITCOIN.balanceOf(BURN_ADDRESS), 301);
    }

    function test_happyPath_noRemainderForEgregore() public {
        vm.warp(0);
        fundContractWithLink();

        enterHolder(address(101), 1);
        enterHolder(address(102), 2);

        vm.warp(egregore.CLOSE_TIME());
        egregore.beginCeremony();

        fulfillRandom(1);
        egregore.payout();

        assertEq(BITCOIN.balanceOf(address(102)), 3);
        assertEq(BITCOIN.balanceOf(BURN_ADDRESS), 0);

        egregore.withdrawLink();
    }

    function test_failOnEarlyPayout() public {
        vm.warp(0);
        fundContractWithLink();

        enterHolder(address(101), 1);
        enterHolder(address(102), 2);

        vm.warp(egregore.CLOSE_TIME());
        egregore.beginCeremony();

        vm.expectRevert();
        egregore.payout();
    }

    function test_retryBeginCeremonyFails_ifBeginCeremonyNotCalled() public {
        fundContractWithLink();
        enterHolder(address(101), 1);
        vm.warp(egregore.CLOSE_TIME());
        vm.expectRevert();
        egregore.retryBeginCeremony(100000);
    }

    function test_retryBeginCeremonySucceeds_ifBeginCeremonyFails() public {
        fundContractWithLink();
        enterHolder(address(101), 1);
        vm.warp(egregore.CLOSE_TIME());
        egregore.beginCeremony();
        egregore.retryBeginCeremony(100000);
    }

    function test_retryBeginCeremonyFails_ifBeginCeremonySucceeds() public {
        fundContractWithLink();
        enterHolder(address(101), 1);
        vm.warp(egregore.CLOSE_TIME());
        egregore.beginCeremony();
        fulfillRandom(100);
        vm.expectRevert();
        egregore.retryBeginCeremony(100000);
    }

    // function test_stressPayoutFunctionGas() public {
    //     vm.warp(0);
    //     fundContractWithLink();

    //     uint32 numHolders = 400;
    //     uint32 amount = 1000;

    //     vm.mockCall(
    //         address(BITCOIN),
    //         abi.encodeWithSelector(BITCOIN.transfer.selector),
    //         abi.encode(true)
    //     );
    //     vm.mockCall(
    //         address(BITCOIN),
    //         abi.encodeWithSelector(BITCOIN.transferFrom.selector),
    //         abi.encode(true)
    //     );
    //     vm.mockCall(
    //         address(BITCOIN),
    //         abi.encodeWithSelector(
    //             BITCOIN.balanceOf.selector,
    //             address(egregore)
    //         ),
    //         abi.encode(10000)
    //     );

    //     for (uint256 i = 0; i < numHolders; i++) {
    //         address holder = address(uint160(100 + i));
    //         vm.mockCall(
    //             address(BITCOIN),
    //             abi.encodeWithSelector(BITCOIN.balanceOf.selector, holder),
    //             abi.encode(amount)
    //         );
    //         enterHolder(holder, amount);
    //     }

    //     vm.warp(egregore.CLOSE_TIME());
    //     egregore.beginCeremony();
    //     fulfillRandom(egregore.totalPenitences() - 1);
    //     egregore.payout();
    // }

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

    function enterHolder(address holder, uint256 amount) private {
        vm.prank(BITCOIN_UNISWAP_POOL);
        BITCOIN.transfer(holder, amount);
        vm.startPrank(holder);
        BITCOIN.approve(address(egregore), BITCOIN.balanceOf(holder));
        egregore.sacrifice(amount);

        // Burn rest of balance to make calculations easier
        uint256 remainingBalance = BITCOIN.balanceOf(holder);
        if (remainingBalance > 0) {
            BITCOIN.transfer(address(1), remainingBalance);
        }
        vm.stopPrank();
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
