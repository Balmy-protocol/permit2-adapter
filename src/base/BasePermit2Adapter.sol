// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IBasePermit2Adapter, IPermit2 } from "../interfaces/IBasePermit2Adapter.sol";
import { Token } from "../libraries/Token.sol";

/**
 * @title Base Permit2 Adapter
 * @author Sam Bugs
 * @notice The base contract for Permit2 adapters
 */
abstract contract BasePermit2Adapter is IBasePermit2Adapter, IERC1271 {
  using Address for address;

  /// @inheritdoc IBasePermit2Adapter
  address public constant NATIVE_TOKEN = Token.NATIVE_TOKEN;
  /// @inheritdoc IBasePermit2Adapter
  // solhint-disable-next-line var-name-mixedcase
  IPermit2 public immutable PERMIT2;

  bytes4 private constant MAGIC_WORD = IERC1271.isValidSignature.selector;

  constructor(IPermit2 _permit2) {
    PERMIT2 = _permit2;
  }

  // solhint-disable-next-line no-empty-blocks
  receive() external payable { }

  function isValidSignature(bytes32, bytes memory) external view returns (bytes4 magicValue) {
    // Note: both swap and arbitrary adapters support approving tokens for other addresses, for integrations to work. The
    //       thing is that sometimes, these third party contracts use Permit2 instead of using ERC20's transfer from.
    //       When that happens, the allowance target will need to be the Permit2 contract, and then Permit2 will call
    //       this function to make sure we authorize the  extraction of tokens. Since this contract is not meant to hold
    //       any funds outside of the scope of a swap or arbitrary execution, we'll allow it
    return msg.sender == address(PERMIT2) ? MAGIC_WORD : bytes4(0);
  }

  modifier checkDeadline(uint256 _deadline) {
    if (block.timestamp > _deadline) revert TransactionDeadlinePassed(block.timestamp, _deadline);
    _;
  }

  function _callContract(address _target, bytes calldata _data, uint256 _value) internal returns (bytes memory _result) {
    if (_target == address(PERMIT2)) revert InvalidContractCall();
    return _target.functionCallWithValue(_data, _value);
  }
}
