// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IDCAHub {
  struct UserPosition {
    address from;
    address to;
    uint32 swapInterval;
    uint32 swapsExecuted;
    uint256 swapped;
    uint32 swapsLeft;
    uint256 remaining;
    uint120 rate;
  }

  /// @notice Set of possible permissions
  enum Permission {
    INCREASE,
    REDUCE,
    WITHDRAW,
    TERMINATE
  }

  /// @notice A set of permissions for a specific operator
  struct PermissionSet {
    // The address of the operator
    address operator;
    // The permissions given to the overator
    Permission[] permissions;
  }

  function userPosition(uint256 positionId) external view returns (UserPosition memory position);

  function deposit(
    address from,
    address to,
    uint256 amount,
    uint32 amountOfSwaps,
    uint32 swapInterval,
    address owner,
    PermissionSet[] calldata permissions
  )
    external
    returns (uint256 positionId);
}
