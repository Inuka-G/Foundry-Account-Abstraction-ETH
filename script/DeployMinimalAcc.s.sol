// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MinimumAccount} from "../src/MinimumAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimalAccount is Script {
    MinimumAccount minimumAccount;

    function run() public {}

    function deployMinimalAccount() public returns (HelperConfig, MinimumAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.startBroadcast(config.account);
        // vm.startBroadcast(address(6));
        minimumAccount = new MinimumAccount(config.entryPoint);
        minimumAccount.transferOwnership(config.account);
        vm.stopBroadcast();
        return (helperConfig, minimumAccount);
    }
}
