// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { BasePermit2Adapter, IERC1271 } from "../../src/base/BasePermit2Adapter.sol";
import { MockPermit2, IPermit2 } from "./mocks/MockPermit2.sol";

contract BasePermit2AdapterTest is PRBTest, StdUtils {
  
  MockPermit2 internal permit2;
  BasePermit2Adapter internal adapter;

  function setUp() public virtual {
    permit2 = new MockPermit2();
    adapter = new Impl(permit2);
  }

  function testFuzz_isValidSignature_DoesNotReturnMagicWordWhenNotPermit2(bytes32 _hash, bytes memory _signature) public {
    assertNotEq(adapter.isValidSignature(_hash, _signature), IERC1271.isValidSignature.selector);
  }

  function testFuzz_isValidSignature_ReturnsMagicWordWhenPermit2(bytes32 _hash, bytes memory _signature) public {
    vm.prank(address(permit2));
    assertEq(adapter.isValidSignature(_hash, _signature), IERC1271.isValidSignature.selector);
  }
}

contract Impl is BasePermit2Adapter {
  constructor(IPermit2 permit2) BasePermit2Adapter(permit2) {}
 }