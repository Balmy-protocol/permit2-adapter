// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { IBasePermit2Adapter } from "../../src/interfaces/IBasePermit2Adapter.sol";
import { MockPermit2 } from "./mocks/MockPermit2.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { ArbitraryExecutionPermit2AdapterInstance } from "./instances/ArbitraryExecutionPermit2AdapterInstance.sol";
import { Utils } from "../Utils.sol";

contract ArbitraryExecutionPermit2AdapterTest is PRBTest, StdUtils {
  address internal alice = address(1);
  address internal bob = address(2);
  MockPermit2 internal permit2;
  MockERC20 internal tokenIn;
  MockERC20 internal tokenOut;
  ArbitraryExecutionPermit2AdapterInstance internal adapter;
  TargetContract internal target;

  function setUp() public virtual {
    permit2 = new MockPermit2();
    tokenIn = new MockERC20();
    tokenOut = new MockERC20();
    adapter = new ArbitraryExecutionPermit2AdapterInstance(permit2);
    target = new TargetContract();
  }

  function testFuzz_executeWithPermit_RevertWhen_DeadlineHasPassed(uint256 _timestamp) public {
    vm.assume(_timestamp > 0);
    vm.warp(_timestamp);

    vm.expectRevert(
      abi.encodeWithSelector(IBasePermit2Adapter.TransactionDeadlinePassed.selector, _timestamp, _timestamp - 1)
    );
    adapter.executeWithPermit(
      Utils.buildEmptyPermit(),
      Utils.buildEmptyAllowanceTargets(),
      Utils.buildEmptyContractCalls(),
      Utils.buildEmptyTransferOut(),
      _timestamp - 1
    );
  }

  function test_executeWithPermit_WorksWhenNothingIsExecuted() public {
    // Prepare call assertions
    vm.expectCall(
      address(permit2),
      // solhint-disable max-line-length
      abi.encodeWithSignature("permitTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes)"),
      0
    ); // Permit2 was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.approve.selector), 0); // Approve was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.transfer.selector), 0); // Transfer was not called
    vm.expectCall(address(tokenOut), abi.encodeWithSelector(tokenOut.transfer.selector), 0); // Transfer was not called

    // Execute
    (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithPermit(
      Utils.buildEmptyPermit(),
      Utils.buildEmptyAllowanceTargets(),
      Utils.buildEmptyContractCalls(),
      Utils.buildEmptyTransferOut(),
      type(uint256).max
    );

    // Assertions
    assertEq(_executionResults.length, 0);
    assertEq(_tokenBalances.length, 0);
  }

  function testFuzz_executeWithPermit_WorksWithNative(uint256 _nativeAmount, uint240 _tokenOutAmount) public {
    // So we can transfer the necessary amount
    _nativeAmount = bound(_nativeAmount, 0, address(this).balance);

    // Prepare execution
    address _target = address(target);
    bytes memory _data = abi.encodeWithSelector(target.someFunction.selector, _nativeAmount, tokenOut, _tokenOutAmount);

    // Prepare call assertions
    vm.expectCall(
      address(permit2),
      // solhint-disable max-line-length
      abi.encodeWithSignature("permitTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes)"),
      0
    ); // Permit2 was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.approve.selector), 0); // Approve was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.transfer.selector), 0); // Transfer was not called

    // Execute
    (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithPermit{
      value: _nativeAmount
    }(
      Utils.buildEmptyPermit(),
      Utils.buildEmptyAllowanceTargets(),
      Utils.buildContractCalls(_target, _data, _nativeAmount),
      Utils.buildTransferOut(address(tokenOut), Utils.buildDistribution(alice, 2500, bob)),
      type(uint256).max
    );

    // Assertions
    assertEq(_executionResults.length, 1);
    uint256 _decoded = abi.decode(_executionResults[0], (uint256));
    assertEq(_decoded, _nativeAmount);
    assertEq(_tokenBalances.length, 1);
    assertEq(_tokenBalances[0], _tokenOutAmount);
    uint256 _aliceAmount = uint256(_tokenOutAmount) * 25 / 100;
    assertEq(tokenOut.balanceOf(alice), _aliceAmount);
    assertEq(tokenOut.balanceOf(bob), _tokenOutAmount - _aliceAmount);
  }

  function testFuzz_executeWithPermit_WorksWithERC20(
    uint256 _tokenInAmount,
    uint248 _tokenOutAmount,
    uint256 _nonce,
    bytes calldata _signature
  )
    public
  {
    // Give alice some tokens
    tokenIn.mint(alice, _tokenInAmount);

    // Execute
    vm.prank(alice);
    (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithPermit(
      Utils.buildPermit(address(tokenIn), _tokenInAmount, _nonce, _signature),
      Utils.buildAllowanceTargets(address(target), address(tokenIn)),
      Utils.buildContractCalls(
        address(target),
        abi.encodeWithSelector(target.takeFrom.selector, tokenIn, _tokenInAmount, tokenOut, _tokenOutAmount),
        0
      ),
      Utils.buildTransferOut(address(tokenOut), Utils.buildDistribution(bob)),
      type(uint256).max
    );

    // Assertions
    assertEq(_executionResults.length, 1);
    uint256 _decoded = abi.decode(_executionResults[0], (uint256));
    assertEq(_decoded, _tokenInAmount);
    assertEq(_tokenBalances.length, 1);
    assertEq(_tokenBalances[0], _tokenOutAmount);
    assertEq(tokenIn.balanceOf(alice), 0);
    assertEq(tokenIn.balanceOf(address(target)), _tokenInAmount);
    assertEq(tokenOut.balanceOf(alice), 0);
    assertEq(tokenOut.balanceOf(bob), _tokenOutAmount);
    assertEq(tokenIn.allowance(address(adapter), address(target)), type(uint256).max);
  }

  function testFuzz_executeWithBatchPermit_RevertWhen_DeadlineHasPassed(uint256 _timestamp) public {
    vm.assume(_timestamp > 0);
    vm.warp(_timestamp);

    vm.expectRevert(
      abi.encodeWithSelector(IBasePermit2Adapter.TransactionDeadlinePassed.selector, _timestamp, _timestamp - 1)
    );
    adapter.executeWithBatchPermit(
      Utils.buildEmptyBatchPermit(),
      Utils.buildEmptyAllowanceTargets(),
      Utils.buildEmptyContractCalls(),
      Utils.buildEmptyTransferOut(),
      _timestamp - 1
    );
  }

  function test_executeWithBatchPermit_WorksWhenNothingIsExecuted() public {
    // Prepare call assertions
    vm.expectCall(
      address(permit2),
      abi.encodeWithSignature(
        // solhint-disable max-line-length
        "permitTransferFrom(((address,uint256)[],uint256,uint256),(address,uint256),address,bytes)"
      ),
      0
    ); // Permit2 was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.approve.selector), 0); // Approve was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.transfer.selector), 0); // Transfer was not called
    vm.expectCall(address(tokenOut), abi.encodeWithSelector(tokenOut.transfer.selector), 0); // Transfer was not called

    // Execute
    (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithBatchPermit(
      Utils.buildEmptyBatchPermit(),
      Utils.buildEmptyAllowanceTargets(),
      Utils.buildEmptyContractCalls(),
      Utils.buildEmptyTransferOut(),
      type(uint256).max
    );

    // Assertions
    assertEq(_executionResults.length, 0);
    assertEq(_tokenBalances.length, 0);
  }

  function testFuzz_executeWithBatchPermit_WorksWithNative(uint256 _nativeAmount, uint240 _tokenOutAmount) public {
    // So we can transfer the necessary amount
    _nativeAmount = bound(_nativeAmount, 0, address(this).balance);

    // Prepare execution
    address _target = address(target);
    bytes memory _data = abi.encodeWithSelector(target.someFunction.selector, _nativeAmount, tokenOut, _tokenOutAmount);

    // Prepare call assertions
    vm.expectCall(
      address(permit2),
      abi.encodeWithSignature(
        "permitTransferFrom(((address,uint256)[],uint256,uint256),(address,uint256),address,bytes)"
      ),
      0
    ); // Permit2 was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.approve.selector), 0); // Approve was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.transfer.selector), 0); // Transfer was not called

    // Execute
    (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithBatchPermit{
      value: _nativeAmount
    }(
      Utils.buildEmptyBatchPermit(),
      Utils.buildEmptyAllowanceTargets(),
      Utils.buildContractCalls(_target, _data, _nativeAmount),
      Utils.buildTransferOut(address(tokenOut), Utils.buildDistribution(alice, 2500, bob)),
      type(uint256).max
    );

    // Assertions
    assertEq(_executionResults.length, 1);
    uint256 _decoded = abi.decode(_executionResults[0], (uint256));
    assertEq(_decoded, _nativeAmount);
    assertEq(_tokenBalances.length, 1);
    assertEq(_tokenBalances[0], _tokenOutAmount);
    uint256 _aliceAmount = uint256(_tokenOutAmount) * 25 / 100;
    assertEq(tokenOut.balanceOf(alice), _aliceAmount);
    assertEq(tokenOut.balanceOf(bob), _tokenOutAmount - _aliceAmount);
  }

  function testFuzz_executeWithBatchPermit_WorksWithERC20(
    uint256 _tokenInAmount,
    uint248 _tokenOutAmount,
    uint256 _nonce,
    bytes calldata _signature
  )
    public
  {
    // Give alice some tokens
    tokenIn.mint(alice, _tokenInAmount);

    // Execute
    vm.prank(alice);
    (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithBatchPermit(
      Utils.buildBatchPermit(address(tokenIn), _tokenInAmount, _nonce, _signature),
      Utils.buildAllowanceTargets(address(target), address(tokenIn)),
      Utils.buildContractCalls(
        address(target),
        abi.encodeWithSelector(target.takeFrom.selector, tokenIn, _tokenInAmount, tokenOut, _tokenOutAmount),
        0
      ),
      Utils.buildTransferOut(address(tokenOut), Utils.buildDistribution(bob)),
      type(uint256).max
    );

    // Assertions
    assertEq(_executionResults.length, 1);
    uint256 _decoded = abi.decode(_executionResults[0], (uint256));
    assertEq(_decoded, _tokenInAmount);
    assertEq(_tokenBalances.length, 1);
    assertEq(_tokenBalances[0], _tokenOutAmount);
    assertEq(tokenIn.balanceOf(alice), 0);
    assertEq(tokenIn.balanceOf(address(target)), _tokenInAmount);
    assertEq(tokenOut.balanceOf(alice), 0);
    assertEq(tokenOut.balanceOf(bob), _tokenOutAmount);
    assertEq(tokenIn.allowance(address(adapter), address(target)), type(uint256).max);
  }
}

contract TargetContract {
  function someFunction(uint256 _sentValue, MockERC20 _token, uint256 _amountToMint) external payable returns (uint256) {
    require(_sentValue == msg.value, "Invalid param");
    _token.mint(msg.sender, _amountToMint);
    return _sentValue;
  }

  function takeFrom(
    MockERC20 _tokenToTake,
    uint256 _amountToTake,
    MockERC20 _tokenToReturn,
    uint256 _amountToReturn
  )
    external
    payable
    returns (uint256)
  {
    _tokenToTake.transferFrom(msg.sender, address(this), _amountToTake);
    _tokenToReturn.mint(msg.sender, _amountToReturn);
    return _amountToTake;
  }
}
