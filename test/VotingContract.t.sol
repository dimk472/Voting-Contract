// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {VotingContract} from "../src/VotingContract.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CounterTest is Test {
    VotingContract public votingContract;

    function setUp() public {
        votingContract = new VotingContract();
    }

    function testCreateVoting() public {
        uint256 durationInSeconds = 60;

        votingContract.createVoting("Test Voting", durationInSeconds);

        assertEq(
            votingContract.votingDeadline(),
            block.timestamp + durationInSeconds
        );
    }

    function testCreateVotingWhenNotOwner() public {
        uint256 durationInSeconds = 60;

        vm.prank(address(0x123));

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(0x123)
            )
        );

        votingContract.createVoting("Test Voting", durationInSeconds);
    }

    function testCreateVotingWhenTimeIsNotOver() public {
        uint256 durationInSeconds = 60;

        votingContract.createVoting("Test Voting", durationInSeconds);

        vm.expectRevert(VotingContract.TimeIsOver.selector);

        votingContract.createVoting("Another Voting", durationInSeconds);
    }

    function testCreateVotingWithInvalidDuration() public {
        uint256 invalidDuration = 0;

        vm.expectRevert(VotingContract.wrongDuration.selector);

        votingContract.createVoting("Test Voting", invalidDuration);
    }

    function testCreateParticipants() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        (string memory name, address participantAddress, ) = votingContract
            .participants(0);

        assertEq(name, "Alice");
        assertEq(participantAddress, address(0x1));

        (name, participantAddress, ) = votingContract.participants(1);

        assertEq(name, "Bob");
        assertEq(participantAddress, address(0x2));
    }

    function testCreateParticipantsWhenNotOwner() public {
        votingContract.createVoting("Test Voting", 60);

        vm.prank(address(0x123));

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(0x123)
            )
        );

        votingContract.createParticipants("Alice", address(0x1));
    }

    function testCreateParticipantsWhenAlreadyExists() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));

        vm.expectRevert(VotingContract.ParticipantAlreadyExists.selector);

        votingContract.createParticipants("Alice", address(0x1));
    }

    function testCreateParticipantsWithSameAddress() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));

        vm.expectRevert(VotingContract.ParticipantAlreadyExists.selector);

        votingContract.createParticipants("Bob", address(0x1));
    }

    function testCreateParticipantsWithSameName() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Alice", address(0x2));

        (string memory name, address participantAddress, ) = votingContract
            .participants(1);

        assertEq(name, "Alice");
        assertEq(participantAddress, address(0x2));
    }

    function testVote() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.prank(address(0x1));

        votingContract.vote(address(0x2));

        (, , uint256 votes) = votingContract.participants(1);

        assertEq(votes, 1);
    }

    function testVoteWhenNotParticipant() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.prank(address(0x3));

        vm.expectRevert(VotingContract.ParticipantDoesNotExist.selector);

        votingContract.vote(address(0x4));
    }

    function testVoteWhenTimeIsOver() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.warp(block.timestamp + 61);

        vm.prank(address(0x1));

        vm.expectRevert(VotingContract.TimeIsOver.selector);

        votingContract.vote(address(0x2));
    }

    function testVoteWhenVotingNotCreated() public {
        vm.prank(address(0x1));

        vm.expectRevert(VotingContract.TimeIsOver.selector);

        votingContract.vote(address(0x2));
    }

    function testVoteWhenAlreadyVoted() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.prank(address(0x1));

        votingContract.vote(address(0x2));

        vm.prank(address(0x1));

        vm.expectRevert(VotingContract.YouHaveAlreadyVoted.selector);

        votingContract.vote(address(0x2));
    }

    function testFinishVoting() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.prank(address(0x1));

        votingContract.vote(address(0x2));

        vm.warp(block.timestamp + 61);

        (string memory winnerName, uint256 winnerVotes) = votingContract
            .finishVoting();

        assertEq(winnerName, "Bob");
        assertEq(winnerVotes, 1);
    }

    function testFinishVotingWhenTimeIsNotOver() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.prank(address(0x1));

        votingContract.vote(address(0x2));

        vm.expectRevert(VotingContract.TimeIsOver.selector);

        votingContract.finishVoting();
    }

    function testFinishVotingWhenNoParticipants() public {
        votingContract.createVoting("Test Voting", 60);

        vm.warp(block.timestamp + 61);

        (string memory winnerName, uint256 winnerVotes) = votingContract
            .finishVoting();

        assertEq(winnerName, "");
        assertEq(winnerVotes, 0);
    }

    function testFinishVotingWhenNoVotes() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.warp(block.timestamp + 61);

        (string memory winnerName, uint256 winnerVotes) = votingContract
            .finishVoting();

        assertEq(winnerName, "Alice & Bob");
        assertEq(winnerVotes, 0);
    }

    function testFinishVotingWhenTie() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.prank(address(0x1));
        votingContract.vote(address(0x2));

        vm.prank(address(0x2));
        votingContract.vote(address(0x1));

        vm.warp(block.timestamp + 61);

        (string memory winnerName, uint256 winnerVotes) = votingContract
            .finishVoting();

        assertEq(winnerName, "Alice & Bob");
        assertEq(winnerVotes, 1);
    }

    function testResetVoting() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.prank(address(0x1));
        votingContract.vote(address(0x2));

        vm.warp(block.timestamp + 61);

        votingContract.finishVoting();

        assertEq(votingContract.getParticipantsCount(), 0);
    }

    function testResetVotingWhenNotOwner() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.warp(block.timestamp + 61);

        vm.prank(address(0x123));

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(0x123)
            )
        );

        votingContract.resetVoting();
    }

    function testResetVotingWhenTimeIsNotOver() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        vm.expectRevert(VotingContract.TimeIsOver.selector);

        votingContract.resetVoting();
    }

    function testGetParticipantsCount() public {
        votingContract.createVoting("Test Voting", 60);

        votingContract.createParticipants("Alice", address(0x1));
        votingContract.createParticipants("Bob", address(0x2));

        uint256 count = votingContract.getParticipantsCount();

        assertEq(count, 2);
    }
}
