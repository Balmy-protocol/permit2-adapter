// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import { Token } from "../libraries/Token.sol";
import { IBasePermit2Adapter } from "./IBasePermit2Adapter.sol";

interface ISwapPermit2Adapter is IBasePermit2Adapter {
  /**
   * @notice Thrown when the swap produced less token out than expected
   * @param received The amount of token out received
   * @param expected The amount of token out expected
   */
  error ReceivedTooLittleTokenOut(uint256 received, uint256 expected);

  /**
   * @notice Emitted when a swap ocurrs
   * @param caller The swap caller
   * @param swapType The swap type, 'buy' or 'sell'
   * @param tokenIn The token swapped
   * @param tokenOut The token received
   * @param amountIn The amount of token in swapped
   * @param amountOut The amount of token out received
   * @param swapper The aggregator address
   * @param misc Misc bytes
   */
  event SwapSucceded(
    address caller,
    string swapType,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    address swapper,
    bytes misc
  );

  /// @notice Swap params for a sell order
  struct SellOrderSwapParams {
    // Deadline
    uint256 deadline;
    // Take from caller
    address tokenIn;
    uint256 amountIn;
    uint256 nonce;
    bytes signature;
    // Swap approval
    address allowanceTarget;
    // Swap execution
    address swapper;
    bytes swapData;
    // Swap validation
    address tokenOut;
    uint256 minAmountOut;
    // Transfer token out
    Token.DistributionTarget[] transferOut;
    bytes misc;
  }

  // @notice Swap params for a buy order
  struct BuyOrderSwapParams {
    // Deadline
    uint256 deadline;
    // Take from caller
    address tokenIn;
    uint256 maxAmountIn;
    uint256 nonce;
    bytes signature;
    // Swap approval
    address allowanceTarget;
    // Swap execution
    address swapper;
    bytes swapData;
    // Swap validation
    address tokenOut;
    uint256 amountOut;
    // Transfer token out
    Token.DistributionTarget[] transferOut;
    // Transfer token in
    address unspentTokenInRecipient;
    bytes misc;
  }

  /**
   * @notice Executes a sell order swap by proxing to another contract, but using Permit2 to transfer tokens from the
   * caller
   * @param params The swap's data, such as tokens, amounts, recipient, etc
   * @return amountIn The amount ot `token in` spent on the swap
   * @return amountOut The amount of `token out` produced by the proxied swap
   */
  function sellOrderSwap(SellOrderSwapParams calldata params)
    external
    payable
    returns (uint256 amountIn, uint256 amountOut);

  /**
   * @notice Executes a buy order swap by proxing to another contract, but using Permit2 to transfer tokens from the
   * caller
   * @param params The swap's data, such as tokens, amounts, recipient, etc
   * @return amountIn The amount ot `token in` spent on the swap
   * @return amountOut The amount of `token out` produced by the proxied swap
   */
  function buyOrderSwap(BuyOrderSwapParams calldata params)
    external
    payable
    returns (uint256 amountIn, uint256 amountOut);
}
