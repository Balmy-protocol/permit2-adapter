// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { Vm } from "forge-std/Vm.sol";
import { IPermit2 } from "../src/interfaces/external/IPermit2.sol";
import { IArbitraryExecutionPermit2Adapter } from "../src/interfaces/IArbitraryExecutionPermit2Adapter.sol";
import { Token } from "../src/libraries/Token.sol";

library Utils {
  Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  bytes32 private constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");
  bytes32 private constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
    // solhint-disable-next-line max-line-length
    "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
  );

  // solhint-disable-next-line no-empty-blocks
  function buildEmptyPermit() internal pure returns (IArbitraryExecutionPermit2Adapter.SinglePermit memory) { }

  function buildNativePermitWithAmount(uint256 _amount) internal pure returns (IArbitraryExecutionPermit2Adapter.SinglePermit memory _permit) { 
    _permit.amount = _amount;
  }

  function buildPermit(
    address _token,
    uint256 _amount,
    uint256 _nonce,
    bytes memory _signature
  )
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.SinglePermit memory _permit)
  {
    _permit = IArbitraryExecutionPermit2Adapter.SinglePermit({
      token: _token,
      amount: _amount,
      nonce: _nonce,
      signature: _signature
    });
  }

  function buildSignedPermit(
    address _token,
    uint256 _amount,
    uint256 _nonce,
    uint256 _deadline,
    address _spender,
    uint256 _signerKey,
    bytes32 _domainSeparator
  )
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.SinglePermit memory _permit)
  {
    bytes memory _signature = signPermit(_token, _amount, _nonce, _deadline, _spender, _signerKey, _domainSeparator);

    _permit = IArbitraryExecutionPermit2Adapter.SinglePermit({
      token: _token,
      amount: _amount,
      nonce: _nonce,
      signature: _signature
    });
  }

  // solhint-disable-next-line no-empty-blocks
  function buildEmptyBatchPermit() internal pure returns (IArbitraryExecutionPermit2Adapter.BatchPermit memory) { }

  function buildBatchPermit(
    address _token,
    uint256 _amount,
    uint256 _nonce,
    bytes memory _signature
  )
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.BatchPermit memory _permit)
  {
    IPermit2.TokenPermissions[] memory _tokens = new IPermit2.TokenPermissions[](1);
    _tokens[0] = IPermit2.TokenPermissions({ token: _token, amount: _amount });
    _permit = IArbitraryExecutionPermit2Adapter.BatchPermit({ tokens: _tokens, nonce: _nonce, signature: _signature });
  }

  function buildEmptyAllowanceTargets()
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.AllowanceTarget[] memory _allowanceTargets)
  {
    _allowanceTargets = new IArbitraryExecutionPermit2Adapter.AllowanceTarget[](0);
  }

  function buildAllowanceTargets(
    address _target,
    address _token
  )
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.AllowanceTarget[] memory _allowanceTargets)
  {
    _allowanceTargets = new IArbitraryExecutionPermit2Adapter.AllowanceTarget[](1);
    _allowanceTargets[0] =
      IArbitraryExecutionPermit2Adapter.AllowanceTarget({ allowanceTarget: _target, token: _token });
  }

  function buildEmptyContractCalls()
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.ContractCall[] memory _contractCalls)
  {
    _contractCalls = new IArbitraryExecutionPermit2Adapter.ContractCall[](0);
  }

  function buildContractCalls(
    address _target,
    bytes memory _data,
    uint256 _value
  )
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.ContractCall[] memory _contractCalls)
  {
    _contractCalls = new IArbitraryExecutionPermit2Adapter.ContractCall[](1);
    _contractCalls[0] = IArbitraryExecutionPermit2Adapter.ContractCall({ target: _target, data: _data, value: _value });
  }

  function buildEmptyTransferOut()
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.TransferOut[] memory _transferOut)
  {
    _transferOut = new IArbitraryExecutionPermit2Adapter.TransferOut[](0);
  }

  function buildTransferOut(
    address _token,
    Token.DistributionTarget[] memory _distribution
  )
    internal
    pure
    returns (IArbitraryExecutionPermit2Adapter.TransferOut[] memory _transferOut)
  {
    _transferOut = new IArbitraryExecutionPermit2Adapter.TransferOut[](1);
    _transferOut[0] = IArbitraryExecutionPermit2Adapter.TransferOut({ token: _token, distribution: _distribution });
  }

  function buildEmptyDistribution() internal pure returns (Token.DistributionTarget[] memory _distribution) {
    _distribution = new Token.DistributionTarget[](0);
  }

  function buildDistribution(address _recipient)
    internal
    pure
    returns (Token.DistributionTarget[] memory _distribution)
  {
    _distribution = new Token.DistributionTarget[](1);
    _distribution[0] = Token.DistributionTarget({ recipient: _recipient, shareBps: 0 });
  }

  function buildDistribution(
    address _recipient1,
    uint256 _shareBps1,
    address _recipient2
  )
    internal
    pure
    returns (Token.DistributionTarget[] memory _distribution)
  {
    _distribution = new Token.DistributionTarget[](2);
    _distribution[0] = Token.DistributionTarget({ recipient: _recipient1, shareBps: _shareBps1 });
    _distribution[1] = Token.DistributionTarget({ recipient: _recipient2, shareBps: 0 });
  }

  function signPermit(
    address _token,
    uint256 _amount,
    uint256 _nonce,
    uint256 _deadline,
    address _spender,
    uint256 _signerKey,
    bytes32 _domainSeparator
  )
    internal
    pure
    returns (bytes memory sig)
  {
    (uint8 v, bytes32 r, bytes32 s) =
      VM.sign(_signerKey, _getEIP712Hash(_token, _amount, _nonce, _deadline, _spender, _domainSeparator));
    return abi.encodePacked(r, s, v);
  }

  function _getEIP712Hash(
    address _token,
    uint256 _amount,
    uint256 _nonce,
    uint256 _deadline,
    address _spender,
    bytes32 _domainSeparator
  )
    private
    pure
    returns (bytes32 h)
  {
    return keccak256(
      abi.encodePacked(
        "\x19\x01",
        _domainSeparator,
        keccak256(
          abi.encode(
            PERMIT_TRANSFER_FROM_TYPEHASH,
            keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, _token, _amount)),
            _spender,
            _nonce,
            _deadline
          )
        )
      )
    );
  }
}
