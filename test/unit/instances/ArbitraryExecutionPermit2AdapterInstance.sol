// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ArbitraryExecutionPermit2Adapter } from "../../../src/base/ArbitraryExecutionPermit2Adapter.sol";
import { BasePermit2Adapter, IPermit2 } from "../../../src/base/BasePermit2Adapter.sol";

contract ArbitraryExecutionPermit2AdapterInstance is ArbitraryExecutionPermit2Adapter {
  constructor(IPermit2 _permit2) BasePermit2Adapter(_permit2) { }
}
