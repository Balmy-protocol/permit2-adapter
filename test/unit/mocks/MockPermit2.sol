// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IPermit2 } from "../../../src/interfaces/external/IPermit2.sol";
import { MockERC20 } from "./MockERC20.sol";

contract MockPermit2 is IPermit2 {
  function DOMAIN_SEPARATOR() external pure returns (bytes32) {
    return bytes32(uint256(123_456_790));
  }

  function permitTransferFrom(
    PermitTransferFrom calldata _permit,
    SignatureTransferDetails calldata _transferDetails,
    address _owner,
    bytes calldata
  )
    external
  {
    MockERC20(_permit.permitted.token).burn(_owner, _transferDetails.requestedAmount);
    MockERC20(_permit.permitted.token).mint(_transferDetails.to, _transferDetails.requestedAmount);
  }

  function permitTransferFrom(
    PermitBatchTransferFrom memory _permit,
    SignatureTransferDetails[] calldata _transferDetails,
    address _owner,
    bytes calldata
  )
    external
  {
    for (uint256 i; i < _transferDetails.length; i++) {
      MockERC20(_permit.permitted[i].token).burn(_owner, _transferDetails[i].requestedAmount);
      MockERC20(_permit.permitted[i].token).mint(_transferDetails[i].to, _transferDetails[i].requestedAmount);
    }
  }
}
