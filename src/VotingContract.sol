// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VotingContract is Ownable, ReentrancyGuard {
    error ParticipantAlreadyExists();
    error ParticipantDoesNotExist();
    error YouHaveAlreadyVoted();
    error wrongDuration();
    error TimeIsOver();
    error VotingNotCreated();

    constructor() Ownable(msg.sender) {}

    uint256 public votingDeadline;

    modifier onTime() {
        if (block.timestamp > votingDeadline) {
            revert TimeIsOver();
        }
        _;
    }

    modifier timeIsOver() {
        if (block.timestamp <= votingDeadline) {
            revert TimeIsOver();
        }
        _;
    }

    struct Participant {
        string nameOfParticipant;
        address addressOfParticipant;
        uint256 numberOfVotes;
    }

    event createdVoting(
        uint256 indexed votingId,
        string nameOfVoting,
        uint256 durationInSeconds
    );

    event createdParticipant(
        string nameOfParticipant,
        address addressOfParticipant
    );

    event announcedWinner(
        string winnerName,
        uint256 winnerVotes,
        uint256 votingId
    );

    uint256 public votingId = 0;
    Participant[] public participants;

    mapping(address => uint256) public UserVotings;
    mapping(address => bool) public isParticipant;
    mapping(address => uint256) public IndexOfParticipant;

    function getParticipantsCount() public view returns (uint256) {
        return participants.length;
    }

    function createVoting(
        string memory _nameOfVoting,
        uint256 _durationInSeconds
    ) external onlyOwner timeIsOver {
        if (_durationInSeconds <= 0) {
            revert wrongDuration();
        }
        votingDeadline = block.timestamp + _durationInSeconds;
        votingId++;
        emit createdVoting(votingId, _nameOfVoting, _durationInSeconds);
    }

    function createParticipants(
        string memory _nameOfParticipant,
        address _addressOfParticipant
    ) external onlyOwner {
        if (isParticipant[_addressOfParticipant]) {
            revert ParticipantAlreadyExists();
        }
        isParticipant[_addressOfParticipant] = true;
        participants.push(
            Participant(_nameOfParticipant, _addressOfParticipant, 0)
        );
        IndexOfParticipant[_addressOfParticipant] = participants.length - 1;
        emit createdParticipant(_nameOfParticipant, _addressOfParticipant);
    }

    function vote(address _addressOfParticipant) external nonReentrant onTime {
        if (votingId == 0) {
            revert VotingNotCreated();
        }
        if (!isParticipant[_addressOfParticipant]) {
            revert ParticipantDoesNotExist();
        }
        if (UserVotings[msg.sender] == votingId) {
            revert YouHaveAlreadyVoted();
        }
        uint256 index = IndexOfParticipant[_addressOfParticipant];
        participants[index].numberOfVotes++;
        UserVotings[msg.sender] = votingId;
    }

    function resetVoting() public onlyOwner timeIsOver {
        for (uint256 i = 0; i < participants.length; i++) {
            isParticipant[participants[i].addressOfParticipant] = false;
            delete IndexOfParticipant[participants[i].addressOfParticipant];
        }
        delete participants;
        votingDeadline = 0;
    }

    function finishVoting()
        external
        timeIsOver
        returns (string memory winnerName, uint256 winnerVotes)
    {
        for (uint256 i = 0; i < participants.length; i++) {
            if (i == 0 || participants[i].numberOfVotes > winnerVotes) {
                winnerVotes = participants[i].numberOfVotes;
                winnerName = participants[i].nameOfParticipant;
            } else if (participants[i].numberOfVotes == winnerVotes) {
                winnerName = string(
                    abi.encodePacked(
                        winnerName,
                        " & ",
                        participants[i].nameOfParticipant
                    )
                );
            }
        }
        emit announcedWinner(winnerName, winnerVotes, votingId);

        resetVoting();

        return (winnerName, winnerVotes);
    }
}
