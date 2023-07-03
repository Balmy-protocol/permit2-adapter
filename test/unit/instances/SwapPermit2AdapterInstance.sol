// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { SwapPermit2Adapter } from "../../../src/base/SwapPermit2Adapter.sol";
// solhint-disable-next-line no-unused-import
import { BasePermit2Adapter, IPermit2 } from "../../../src/base/BasePermit2Adapter.sol";

contract SwapPermit2AdapterInstance is SwapPermit2Adapter {
  constructor(IPermit2 _permit2) BasePermit2Adapter(_permit2) { }
}
