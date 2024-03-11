// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SamDAO.sol";
import "../src/SamToken.sol";

contract SamDAOTest is Test {
    SamDAO dao;
    address private nobody = address(0x1);
    address private owner = address(0x2);

    function setUp() public {
        vm.prank(owner);
        dao = new SamDAO();
    }

    function test_whenContractDeployed_thenMintsTokenToDeployer() public {
        SamToken token = SamToken(address(dao.samToken()));        
        assertEq(token.balanceOf(owner), 1);
    }

    function test_whenSubmitProposal_andUnequalNumberOfParameters_thenReverts() public {
        vm.startPrank(owner);

        vm.expectRevert();
        dao.submitProposal(
            new address[](2),
            new uint256[](1),
            new bytes[](1),
            "test"
        );
        
        vm.expectRevert();
        dao.submitProposal(
            new address[](1),
            new uint256[](2),
            new bytes[](1),
            "test"
        );

        vm.expectRevert();
        dao.submitProposal(
            new address[](1),
            new uint256[](1),
            new bytes[](2),
            "test"
        );

        vm.stopPrank();
    }

    function test_givenCallerIsNotMember_whenSubmitProposal_thenReverts() public {
        vm.prank(nobody);
        vm.expectRevert();
        dao.submitProposal(
            new address[](1),
            new uint256[](1),
            new bytes[](1),
            "test"
        );
    }

    function test_givenCallerIsMember_whenSubmitProposal_thenEmitsEvent() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory description = "test";

        vm.expectEmit(false, false, false, true);
        emit ProposalSubmitted(
            dao._hashProposal(targets, values, calldatas, keccak256(bytes(description))),
            targets,
            values,
            calldatas,
            description
        );
    
        vm.prank(owner);
        dao.submitProposal(
            targets,
            values,
            calldatas,
            description
        );

        // TODO:
    }

    event ProposalSubmitted(
        uint256 proposalId,
        address[] targets, 
        uint256[] values,
        bytes[] calldatas,
        string description
    );
}
