const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("VotingContract", function () {
  let votingContract;
  let owner;
  let alice;
  let bob;
  let charlie;
  let notOwner;

  beforeEach(async function () {
    [owner, alice, bob, charlie, notOwner] = await ethers.getSigners();
    const VotingContract = await ethers.getContractFactory("VotingContract");
    votingContract = await VotingContract.deploy();
    await votingContract.waitForDeployment();
  });

  describe("createVoting", function () {
    it("sets voting deadline from duration", async function () {
      const durationInSeconds = 60n;
      const tx = await votingContract.createVoting("Test Voting", durationInSeconds);
      await tx.wait();

      const deadline = await votingContract.votingDeadline();
      const block = await ethers.provider.getBlock("latest");
      expect(deadline).to.equal(BigInt(block.timestamp) + durationInSeconds);
    });

    it("reverts when caller is not owner", async function () {
      await expect(
        votingContract.connect(notOwner).createVoting("Test Voting", 60)
      )
        .to.be.revertedWithCustomError(votingContract, "OwnableUnauthorizedAccount")
        .withArgs(notOwner.address);
    });

    it("reverts when previous voting has not ended", async function () {
      await votingContract.createVoting("Test Voting", 60);
      await expect(
        votingContract.createVoting("Another Voting", 60)
      ).to.be.revertedWithCustomError(votingContract, "TimeIsOver");
    });

    it("reverts with invalid duration", async function () {
      await expect(
        votingContract.createVoting("Test Voting", 0)
      ).to.be.revertedWithCustomError(votingContract, "wrongDuration");
    });
  });

  describe("createParticipants", function () {
    beforeEach(async function () {
      await votingContract.createVoting("Test Voting", 60);
    });

    it("stores participants", async function () {
      await votingContract.createParticipants("Alice", alice.address);
      await votingContract.createParticipants("Bob", bob.address);

      const p0 = await votingContract.participants(0);
      expect(p0.nameOfParticipant).to.equal("Alice");
      expect(p0.addressOfParticipant).to.equal(alice.address);

      const p1 = await votingContract.participants(1);
      expect(p1.nameOfParticipant).to.equal("Bob");
      expect(p1.addressOfParticipant).to.equal(bob.address);
    });

    it("reverts when caller is not owner", async function () {
      await expect(
        votingContract.connect(notOwner).createParticipants("Alice", alice.address)
      )
        .to.be.revertedWithCustomError(votingContract, "OwnableUnauthorizedAccount")
        .withArgs(notOwner.address);
    });

    it("reverts when participant address already exists", async function () {
      await votingContract.createParticipants("Alice", alice.address);
      await expect(
        votingContract.createParticipants("Alice", alice.address)
      ).to.be.revertedWithCustomError(votingContract, "ParticipantAlreadyExists");
    });

    it("reverts when reusing the same address with a different name", async function () {
      await votingContract.createParticipants("Alice", alice.address);
      await expect(
        votingContract.createParticipants("Bob", alice.address)
      ).to.be.revertedWithCustomError(votingContract, "ParticipantAlreadyExists");
    });

    it("allows duplicate names with different addresses", async function () {
      await votingContract.createParticipants("Alice", alice.address);
      await votingContract.createParticipants("Alice", bob.address);

      const p1 = await votingContract.participants(1);
      expect(p1.nameOfParticipant).to.equal("Alice");
      expect(p1.addressOfParticipant).to.equal(bob.address);
    });
  });

  describe("vote", function () {
    beforeEach(async function () {
      await votingContract.createVoting("Test Voting", 60);
      await votingContract.createParticipants("Alice", alice.address);
      await votingContract.createParticipants("Bob", bob.address);
    });

    it("increments vote count for the chosen participant", async function () {
      await votingContract.connect(alice).vote(bob.address);

      const bobParticipant = await votingContract.participants(1);
      expect(bobParticipant.numberOfVotes).to.equal(1n);
    });

    it("reverts when voter is not a participant", async function () {
      const [, , , , , outsider] = await ethers.getSigners();
      await expect(
        votingContract.connect(charlie).vote(outsider.address)
      ).to.be.revertedWithCustomError(votingContract, "ParticipantDoesNotExist");
    });

    it("reverts after voting period ends", async function () {
      await time.increase(61);
      await expect(votingContract.connect(alice).vote(bob.address)).to.be.revertedWithCustomError(
        votingContract,
        "TimeIsOver"
      );
    });

    it("reverts when no voting was created", async function () {
      const fresh = await (await ethers.getContractFactory("VotingContract")).deploy();
      await fresh.waitForDeployment();
      await expect(fresh.connect(alice).vote(bob.address)).to.be.revertedWithCustomError(
        fresh,
        "TimeIsOver"
      );
    });

    it("reverts on double vote in the same round", async function () {
      await votingContract.connect(alice).vote(bob.address);
      await expect(votingContract.connect(alice).vote(bob.address)).to.be.revertedWithCustomError(
        votingContract,
        "YouHaveAlreadyVoted"
      );
    });
  });

  describe("finishVoting", function () {
    beforeEach(async function () {
      await votingContract.createVoting("Test Voting", 60);
      await votingContract.createParticipants("Alice", alice.address);
      await votingContract.createParticipants("Bob", bob.address);
    });

    it("returns winner and clears participants after period ends", async function () {
      await votingContract.connect(alice).vote(bob.address);
      await time.increase(61);

      const [winnerName, winnerVotes] = await votingContract.finishVoting.staticCall();
      expect(winnerName).to.equal("Bob");
      expect(winnerVotes).to.equal(1n);

      await votingContract.finishVoting();
      expect(await votingContract.getParticipantsCount()).to.equal(0n);
    });

    it("reverts when voting period is still active", async function () {
      await votingContract.connect(alice).vote(bob.address);
      await expect(votingContract.finishVoting()).to.be.revertedWithCustomError(
        votingContract,
        "TimeIsOver"
      );
    });

    it("returns empty winner when there are no participants", async function () {
      const empty = await (await ethers.getContractFactory("VotingContract")).deploy();
      await empty.waitForDeployment();
      await empty.createVoting("Test Voting", 60);
      await time.increase(61);

      const [winnerName, winnerVotes] = await empty.finishVoting.staticCall();
      expect(winnerName).to.equal("");
      expect(winnerVotes).to.equal(0n);
    });

    it("returns tied names when nobody voted", async function () {
      await time.increase(61);
      const [winnerName, winnerVotes] = await votingContract.finishVoting.staticCall();
      expect(winnerName).to.equal("Alice & Bob");
      expect(winnerVotes).to.equal(0n);
    });

    it("handles a tie with equal top votes", async function () {
      await votingContract.connect(alice).vote(bob.address);
      await votingContract.connect(bob).vote(alice.address);
      await time.increase(61);

      const [winnerName, winnerVotes] = await votingContract.finishVoting.staticCall();
      expect(winnerName).to.equal("Alice & Bob");
      expect(winnerVotes).to.equal(1n);
    });
  });

  describe("resetVoting", function () {
    beforeEach(async function () {
      await votingContract.createVoting("Test Voting", 60);
      await votingContract.createParticipants("Alice", alice.address);
      await votingContract.createParticipants("Bob", bob.address);
    });

    it("is invoked by finishVoting and clears state", async function () {
      await votingContract.connect(alice).vote(bob.address);
      await time.increase(61);
      await votingContract.finishVoting();
      expect(await votingContract.getParticipantsCount()).to.equal(0n);
    });

    it("reverts when caller is not owner", async function () {
      await time.increase(61);
      await expect(votingContract.connect(notOwner).resetVoting())
        .to.be.revertedWithCustomError(votingContract, "OwnableUnauthorizedAccount")
        .withArgs(notOwner.address);
    });

    it("reverts while voting period is still active", async function () {
      await expect(votingContract.resetVoting()).to.be.revertedWithCustomError(
        votingContract,
        "TimeIsOver"
      );
    });
  });

  describe("getParticipantsCount", function () {
    it("returns number of participants", async function () {
      await votingContract.createVoting("Test Voting", 60);
      await votingContract.createParticipants("Alice", alice.address);
      await votingContract.createParticipants("Bob", bob.address);
      expect(await votingContract.getParticipantsCount()).to.equal(2n);
    });
  });
});
