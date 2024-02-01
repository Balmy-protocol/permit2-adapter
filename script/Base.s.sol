// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { Script } from "forge-std/Script.sol";

abstract contract BaseScript is Script {

  /// @dev Needed for the deterministic deployments.
  bytes32 internal constant ZERO_SALT = bytes32(0);

  constructor() {
  }

  modifier broadcaster() {
    vm.startBroadcast();
    _;
    vm.stopBroadcast();
  }
}
