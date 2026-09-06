// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {VotingContract} from "../src/VotingContract.sol";

contract CounterScript is Script {
    VotingContract public votingContract;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        votingContract = new VotingContract();

        vm.stopBroadcast();
    }
}
