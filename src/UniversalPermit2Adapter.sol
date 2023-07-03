// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import { BasePermit2Adapter, IPermit2, Token } from "./base/BasePermit2Adapter.sol";
import {
  IArbitraryExecutionPermit2Adapter,
  ArbitraryExecutionPermit2Adapter
} from "./base/ArbitraryExecutionPermit2Adapter.sol";
import { ISwapPermit2Adapter, SwapPermit2Adapter } from "./base/SwapPermit2Adapter.sol";

/**
 * @title Universal Permit2 Adapter
 * @author Sam Bugs
 * @notice This contracts adds Permit2 capabilities to existing contracts by acting as a proxy
 * @dev It's important to note that this contract should never hold any funds outside of the scope of a transaction,
 *      nor should it be granted "regular" ERC20 token approvals. This contract is meant to be used as a proxy, so
 *      the only tokens approved/transferred through Permit2 should be entirely spent in the same transaction.
 *      Any unspent allowance or remaining tokens on the contract can be transferred by anyone, so please be careful!
 */
contract UniversalPermit2Adapter is SwapPermit2Adapter, ArbitraryExecutionPermit2Adapter {
  constructor(IPermit2 _permit2) BasePermit2Adapter(_permit2) { }
}
