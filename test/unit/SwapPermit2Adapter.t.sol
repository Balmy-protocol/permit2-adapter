// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { ISwapPermit2Adapter, Token } from "../../src/interfaces/ISwapPermit2Adapter.sol";
import { IBasePermit2Adapter } from "../../src/interfaces/IBasePermit2Adapter.sol";
import { MockPermit2 } from "./mocks/MockPermit2.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { SwapPermit2AdapterInstance } from "./instances/SwapPermit2AdapterInstance.sol";
import { Utils } from "../Utils.sol";

contract SwapPermit2AdapterTest is PRBTest, StdUtils {
  event Swapped(
    address caller,
    ISwapPermit2Adapter.SwapType swapType,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 amountOut,
    address swapper,
    bytes misc
  );

  address internal alice = address(1);
  address internal bob = address(2);
  MockPermit2 internal permit2;
  MockERC20 internal tokenIn;
  MockERC20 internal tokenOut;
  SwapPermit2AdapterInstance internal adapter;
  TargetSwapper internal swapper;

  function setUp() public virtual {
    permit2 = new MockPermit2();
    tokenIn = new MockERC20();
    tokenOut = new MockERC20();
    adapter = new SwapPermit2AdapterInstance(permit2);
    swapper = new TargetSwapper();
  }

  function testFuzz_sellOrderSwap_RevertWhen_DeadlineHasPassed(uint256 _timestamp) public {
    vm.assume(_timestamp > 0);
    vm.warp(_timestamp);

    ISwapPermit2Adapter.SellOrderSwapParams memory _params = ISwapPermit2Adapter.SellOrderSwapParams({
      // Just before current timestamp
      deadline: _timestamp - 1,
      tokenIn: address(0),
      amountIn: 0,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(0),
      swapData: "",
      tokenOut: address(0),
      minAmountOut: 0,
      transferOut: new Token.DistributionTarget[](0),
      misc: ""
    });

    vm.expectRevert(
      abi.encodeWithSelector(IBasePermit2Adapter.TransactionDeadlinePassed.selector, _timestamp, _timestamp - 1)
    );
    adapter.sellOrderSwap(_params);
  }

  function test_sellOrderSwap_RevertWhen_CallingPermit2() public {
    ISwapPermit2Adapter.SellOrderSwapParams memory _params = ISwapPermit2Adapter.SellOrderSwapParams({
      // Just before current timestamp
      deadline: type(uint256).max,
      tokenIn: address(0),
      amountIn: 0,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(permit2),
      swapData: "",
      tokenOut: address(0),
      minAmountOut: 0,
      transferOut: new Token.DistributionTarget[](0),
      misc: ""
    });

    vm.expectRevert(abi.encodeWithSelector(IBasePermit2Adapter.InvalidContractCall.selector));
    adapter.sellOrderSwap(_params);
  }

  function testFuzz_sellOrderSwap_NativeToERC20(uint256 _amountIn, uint256 _amountOut) public {
    vm.deal(alice, _amountIn);
    tokenOut.mint(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.SellOrderSwapParams memory _params = ISwapPermit2Adapter.SellOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(0),
      amountIn: _amountIn,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(0), _amountIn, address(tokenOut), _amountOut),
      tokenOut: address(tokenOut),
      minAmountOut: _amountOut,
      transferOut: Utils.buildDistribution(alice),
      misc: ""
    });

    // Prepare call assertions
    vm.expectCall(
      address(permit2),
      // solhint-disable-next-line max-line-length
      abi.encodeWithSignature("permitTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes)"),
      0
    ); // Permit2 was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.approve.selector), 0); // Approve was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.transfer.selector), 0); // Transfer was not called

    // Expect event
    vm.expectEmit();
    emit Swapped({
      caller: address(alice),
      swapType: ISwapPermit2Adapter.SwapType.Sell,
      tokenIn: _params.tokenIn,
      tokenOut: _params.tokenOut,
      amountIn: _params.amountIn,
      amountOut: _amountOut,
      swapper: _params.swapper,
      misc: _params.misc
    });

    // Execute
    vm.prank(alice);
    (uint256 _returnAmountIn, uint256 _returnAmountOut) = adapter.sellOrderSwap{ value: _amountIn }(_params);

    // Assertions
    assertEq(alice.balance, 0, "Token in not taken from alice");
    assertEq(address(swapper).balance, _amountIn, "Token in not sent to swapper");
    assertEq(tokenOut.balanceOf(address(swapper)), 0, "Token out not taken from swapper");
    assertEq(tokenOut.balanceOf(alice), _amountOut, "Token out not sent to alice");
    assertEq(_returnAmountIn, _amountIn, "Invalid returned value for amount in");
    assertEq(_returnAmountOut, _amountOut, "Invalid return value for amount out");
  }

  function testFuzz_sellOrderSwap_RevertWhen_NativeToERC20DoesNotReturnEnoughTokenOut(
    uint256 _amountIn,
    uint256 _amountOut
  )
    public
  {
    _amountOut = bound(_amountOut, 0, type(uint256).max - 1);

    vm.deal(alice, _amountIn);
    tokenOut.mint(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.SellOrderSwapParams memory _params = ISwapPermit2Adapter.SellOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(0),
      amountIn: _amountIn,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(0), _amountIn, address(tokenOut), _amountOut),
      tokenOut: address(tokenOut),
      minAmountOut: _amountOut + 1,
      transferOut: Utils.buildDistribution(alice),
      misc: ""
    });

    // Prepare expectations and execute
    vm.expectRevert(
      abi.encodeWithSelector(ISwapPermit2Adapter.ReceivedTooLittleTokenOut.selector, _amountOut, _amountOut + 1)
    );
    vm.prank(alice);
    adapter.sellOrderSwap{ value: _amountIn }(_params);
  }

  function testFuzz_sellOrderSwap_ERC20ToNative(
    uint256 _amountIn,
    uint256 _amountOut,
    uint256 _nonce,
    bytes calldata _signature
  )
    public
  {
    vm.assume(_signature.length > 0);
    tokenIn.mint(alice, _amountIn);
    vm.deal(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.SellOrderSwapParams memory _params = ISwapPermit2Adapter.SellOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(tokenIn),
      amountIn: _amountIn,
      nonce: _nonce,
      signature: _signature,
      allowanceTarget: address(swapper),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(tokenIn), _amountIn, address(0), _amountOut),
      tokenOut: address(0),
      minAmountOut: _amountOut,
      transferOut: Utils.buildDistribution(alice),
      misc: ""
    });

    // Expect event
    vm.expectEmit();
    emit Swapped({
      caller: address(alice),
      swapType: ISwapPermit2Adapter.SwapType.Sell,
      tokenIn: _params.tokenIn,
      tokenOut: _params.tokenOut,
      amountIn: _params.amountIn,
      amountOut: _amountOut,
      swapper: _params.swapper,
      misc: _params.misc
    });

    // Execute
    vm.prank(alice);
    (uint256 _returnAmountIn, uint256 _returnAmountOut) = adapter.sellOrderSwap(_params);

    // Assertions
    assertEq(tokenIn.balanceOf(alice), 0, "Token in not taken from alice");
    assertEq(tokenIn.balanceOf(address(swapper)), _amountIn, "Token in not sent to swapper");
    assertEq(address(swapper).balance, 0, "Token out not taken from swapper");
    assertEq(alice.balance, _amountOut, "Token out not sent to alice");
    assertEq(_returnAmountIn, _amountIn, "Invalid returned value for amount in");
    assertEq(_returnAmountOut, _amountOut, "Invalid return value for amount out");
    assertEq(tokenIn.allowance(address(adapter), address(swapper)), 1, "Invalid allowance");
  }

  function testFuzz_sellOrderSwap_RevertWhen_ERC20ToNativeDoesNotReturnEnoughTokenOut(
    uint256 _amountIn,
    uint256 _amountOut,
    uint256 _nonce,
    bytes calldata _signature
  )
    public
  {
    vm.assume(_signature.length > 0);
    _amountOut = bound(_amountOut, 0, type(uint256).max - 1);

    tokenIn.mint(alice, _amountIn);
    vm.deal(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.SellOrderSwapParams memory _params = ISwapPermit2Adapter.SellOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(tokenIn),
      amountIn: _amountIn,
      nonce: _nonce,
      signature: _signature,
      allowanceTarget: address(swapper),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(tokenIn), _amountIn, address(0), _amountOut),
      tokenOut: address(0),
      minAmountOut: _amountOut + 1,
      transferOut: Utils.buildDistribution(alice),
      misc: ""
    });

    // Prepare expectations and execute
    vm.expectRevert(
      abi.encodeWithSelector(ISwapPermit2Adapter.ReceivedTooLittleTokenOut.selector, _amountOut, _amountOut + 1)
    );
    vm.prank(alice);
    adapter.sellOrderSwap(_params);
  }

  function testFuzz_sellOrderSwap_MultipleOutRecipients(uint256 _amountIn, uint240 _amountOut) public {
    vm.deal(alice, _amountIn);
    tokenOut.mint(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.SellOrderSwapParams memory _params = ISwapPermit2Adapter.SellOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(0),
      amountIn: _amountIn,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(0), _amountIn, address(tokenOut), _amountOut),
      tokenOut: address(tokenOut),
      minAmountOut: _amountOut,
      transferOut: Utils.buildDistribution(address(0), 2500, bob),
      misc: ""
    });

    // Execute
    vm.prank(alice);
    adapter.sellOrderSwap{ value: _amountIn }(_params);

    // Assertions
    uint256 _expectedBalanceAlice = uint256(_amountOut) * 25 / 100;
    assertEq(tokenOut.balanceOf(address(swapper)), 0, "Token out not taken from swapper");
    assertEq(tokenOut.balanceOf(alice), _expectedBalanceAlice, "Token out not sent to alice");
    assertEq(tokenOut.balanceOf(bob), _amountOut - _expectedBalanceAlice, "Token out not sent to bob");
  }

  function testFuzz_buyOrderSwap_RevertWhen_DeadlineHasPassed(uint256 _timestamp) public {
    vm.assume(_timestamp > 0);
    vm.warp(_timestamp);

    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      // Just before current timestamp
      deadline: _timestamp - 1,
      tokenIn: address(0),
      maxAmountIn: 0,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(0),
      swapData: "",
      tokenOut: address(0),
      amountOut: 0,
      transferOut: Utils.buildEmptyDistribution(),
      unspentTokenInRecipient: address(0),
      misc: ""
    });

    vm.expectRevert(
      abi.encodeWithSelector(IBasePermit2Adapter.TransactionDeadlinePassed.selector, _timestamp, _timestamp - 1)
    );
    adapter.buyOrderSwap(_params);
  }

  function test_buyOrderSwap_RevertWhen_CallingPermit2() public {
    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      // Just before current timestamp
      deadline: type(uint256).max,
      tokenIn: address(0),
      maxAmountIn: 0,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(permit2),
      swapData: "",
      tokenOut: address(0),
      amountOut: 0,
      transferOut: Utils.buildEmptyDistribution(),
      unspentTokenInRecipient: address(0),
      misc: ""
    });

    vm.expectRevert(abi.encodeWithSelector(IBasePermit2Adapter.InvalidContractCall.selector));
    adapter.buyOrderSwap(_params);
  }

  function testFuzz_buyOrderSwap_NativeToERC20(uint256 _amountIn, uint256 _amountOut) public {
    vm.deal(alice, _amountIn);
    tokenOut.mint(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(0),
      maxAmountIn: _amountIn,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(0), _amountIn, address(tokenOut), _amountOut),
      tokenOut: address(tokenOut),
      amountOut: _amountOut,
      transferOut: Utils.buildDistribution(alice),
      unspentTokenInRecipient: address(0),
      misc: ""
    });

    // Prepare call assertions
    vm.expectCall(
      address(permit2),
      // solhint-disable-next-line max-line-length
      abi.encodeWithSignature("permitTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes)"),
      0
    ); // Permit2 was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.approve.selector), 0); // Approve was not called
    vm.expectCall(address(tokenIn), abi.encodeWithSelector(tokenIn.transfer.selector), 0); // Transfer was not called

    // Expect event
    vm.expectEmit();
    emit Swapped({
      caller: address(alice),
      swapType: ISwapPermit2Adapter.SwapType.Buy,
      tokenIn: _params.tokenIn,
      tokenOut: _params.tokenOut,
      amountIn: _amountIn,
      amountOut: _amountOut,
      swapper: _params.swapper,
      misc: _params.misc
    });

    // Execute
    vm.prank(alice);
    (uint256 _returnAmountIn, uint256 _returnAmountOut) = adapter.buyOrderSwap{ value: _amountIn }(_params);

    // Assertions
    assertEq(alice.balance, 0, "Token in not taken from alice");
    assertEq(address(swapper).balance, _amountIn, "Token in not sent to swapper");
    assertEq(tokenOut.balanceOf(address(swapper)), 0, "Token out not taken from swapper");
    assertEq(tokenOut.balanceOf(alice), _amountOut, "Token out not sent to alice");
    assertEq(_returnAmountIn, _amountIn, "Invalid returned value for amount in");
    assertEq(_returnAmountOut, _amountOut, "Invalid return value for amount out");
  }

  function testFuzz_buyOrderSwap_RevertWhen_NativeToERC20DoesNotReturnEnoughTokenOut(
    uint256 _amountIn,
    uint256 _amountOut
  )
    public
  {
    _amountOut = bound(_amountOut, 0, type(uint256).max - 1);

    vm.deal(alice, _amountIn);
    tokenOut.mint(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(0),
      maxAmountIn: _amountIn,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(0), _amountIn, address(tokenOut), _amountOut),
      tokenOut: address(tokenOut),
      amountOut: _amountOut + 1,
      transferOut: Utils.buildDistribution(alice),
      unspentTokenInRecipient: address(0),
      misc: ""
    });

    // Prepare expectations and execute
    vm.expectRevert(
      abi.encodeWithSelector(ISwapPermit2Adapter.ReceivedTooLittleTokenOut.selector, _amountOut, _amountOut + 1)
    );
    vm.prank(alice);
    adapter.buyOrderSwap{ value: _amountIn }(_params);
  }

  function testFuzz_buyOrderSwap_ERC20ToNative(
    uint256 _amountIn,
    uint256 _amountOut,
    uint256 _nonce,
    bytes calldata _signature
  )
    public
  {
    vm.assume(_signature.length > 0);
    tokenIn.mint(alice, _amountIn);
    vm.deal(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(tokenIn),
      maxAmountIn: _amountIn,
      nonce: _nonce,
      signature: _signature,
      allowanceTarget: address(swapper),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(tokenIn), _amountIn, address(0), _amountOut),
      tokenOut: address(0),
      amountOut: _amountOut,
      transferOut: Utils.buildDistribution(alice),
      unspentTokenInRecipient: address(0),
      misc: ""
    });

    // Expect event
    vm.expectEmit();
    emit Swapped({
      caller: address(alice),
      swapType: ISwapPermit2Adapter.SwapType.Buy,
      tokenIn: _params.tokenIn,
      tokenOut: _params.tokenOut,
      amountIn: _amountIn,
      amountOut: _amountOut,
      swapper: _params.swapper,
      misc: _params.misc
    });

    // Execute
    vm.prank(alice);
    (uint256 _returnAmountIn, uint256 _returnAmountOut) = adapter.buyOrderSwap(_params);

    // Assertions
    assertEq(tokenIn.balanceOf(alice), 0, "Token in not taken from alice");
    assertEq(tokenIn.balanceOf(address(swapper)), _amountIn, "Token in not sent to swapper");
    assertEq(address(swapper).balance, 0, "Token out not taken from swapper");
    assertEq(alice.balance, _amountOut, "Token out not sent to alice");
    assertEq(_returnAmountIn, _amountIn, "Invalid returned value for amount in");
    assertEq(_returnAmountOut, _amountOut, "Invalid return value for amount out");
    assertEq(tokenIn.allowance(address(adapter), address(swapper)), 1, "Invalid allowance");
  }

  function testFuzz_buyOrderSwap_RevertWhen_ERC20ToNativeDoesNotReturnEnoughTokenOut(
    uint256 _amountIn,
    uint256 _amountOut,
    uint256 _nonce,
    bytes calldata _signature
  )
    public
  {
    vm.assume(_signature.length > 0);
    _amountOut = bound(_amountOut, 0, type(uint256).max - 1);

    tokenIn.mint(alice, _amountIn);
    vm.deal(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(tokenIn),
      maxAmountIn: _amountIn,
      nonce: _nonce,
      signature: _signature,
      allowanceTarget: address(swapper),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(tokenIn), _amountIn, address(0), _amountOut),
      tokenOut: address(0),
      amountOut: _amountOut + 1,
      transferOut: Utils.buildDistribution(alice),
      unspentTokenInRecipient: address(0),
      misc: ""
    });

    // Prepare expectations and execute
    vm.expectRevert(
      abi.encodeWithSelector(ISwapPermit2Adapter.ReceivedTooLittleTokenOut.selector, _amountOut, _amountOut + 1)
    );
    vm.prank(alice);
    adapter.buyOrderSwap(_params);
  }

  function testFuzz_buyOrderSwap_MultipleOutRecipients(uint256 _amountIn, uint240 _amountOut) public {
    vm.deal(alice, _amountIn);
    tokenOut.mint(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(0),
      maxAmountIn: _amountIn,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(swapper.swap.selector, address(0), _amountIn, address(tokenOut), _amountOut),
      tokenOut: address(tokenOut),
      amountOut: _amountOut,
      transferOut: Utils.buildDistribution(alice, 2500, bob),
      unspentTokenInRecipient: address(0),
      misc: ""
    });

    // Execute
    vm.prank(alice);
    adapter.buyOrderSwap{ value: _amountIn }(_params);

    // Assertions
    uint256 _expectedBalanceAlice = uint256(_amountOut) * 25 / 100;
    assertEq(tokenOut.balanceOf(address(swapper)), 0, "Token out not taken from swapper");
    assertEq(tokenOut.balanceOf(alice), _expectedBalanceAlice, "Token out not sent to alice");
    assertEq(tokenOut.balanceOf(bob), _amountOut - _expectedBalanceAlice, "Token out not sent to bob");
  }

  function testFuzz_buyOrderSwap_ReturnsUnspentNative(
    uint256 _maxAmountIn,
    uint256 _amountUsed,
    uint256 _amountOut
  )
    public
  {
    vm.assume(_maxAmountIn > 1);
    _amountUsed = bound(_amountUsed, 1, _maxAmountIn - 1);

    vm.deal(alice, _maxAmountIn);
    tokenOut.mint(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(0),
      maxAmountIn: _maxAmountIn,
      nonce: 0,
      signature: "",
      allowanceTarget: address(0),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(
        swapper.swapAndReturnUnspent.selector,
        address(0),
        _maxAmountIn,
        _maxAmountIn - _amountUsed,
        address(tokenOut),
        _amountOut
      ),
      tokenOut: address(tokenOut),
      amountOut: _amountOut,
      transferOut: Utils.buildDistribution(alice),
      unspentTokenInRecipient: address(0),
      misc: ""
    });

    // Execute
    vm.prank(alice);
    (uint256 _returnAmountIn, uint256 _returnAmountOut) = adapter.buyOrderSwap{ value: _maxAmountIn }(_params);

    // Assertions
    assertEq(alice.balance, _maxAmountIn - _amountUsed, "Token in not taken from alice");
    assertEq(address(swapper).balance, _amountUsed, "Token in not sent to swapper");
    assertEq(tokenOut.balanceOf(address(swapper)), 0, "Token out not taken from swapper");
    assertEq(tokenOut.balanceOf(alice), _amountOut, "Token out not sent to alice");
    assertEq(_returnAmountIn, _amountUsed, "Invalid returned value for amount in");
    assertEq(_returnAmountOut, _amountOut, "Invalid return value for amount out");
  }

  function testFuzz_buyOrderSwap_ReturnsUnspentERC20(
    uint256 _maxAmountIn,
    uint256 _amountUsed,
    uint256 _amountOut,
    uint256 _nonce,
    bytes calldata _signature
  )
    public
  {
    vm.assume(_signature.length > 0);
    vm.assume(_maxAmountIn > 1);
    _amountUsed = bound(_amountUsed, 1, _maxAmountIn - 1);

    tokenIn.mint(alice, _maxAmountIn);
    vm.deal(address(swapper), _amountOut);

    // Prepare execution
    ISwapPermit2Adapter.BuyOrderSwapParams memory _params = ISwapPermit2Adapter.BuyOrderSwapParams({
      deadline: type(uint256).max,
      tokenIn: address(tokenIn),
      maxAmountIn: _maxAmountIn,
      nonce: _nonce,
      signature: _signature,
      allowanceTarget: address(swapper),
      swapper: address(swapper),
      swapData: abi.encodeWithSelector(
        swapper.swapAndReturnUnspent.selector,
        address(tokenIn),
        _maxAmountIn,
        _maxAmountIn - _amountUsed,
        address(0),
        _amountOut
      ),
      tokenOut: address(0),
      amountOut: _amountOut,
      transferOut: Utils.buildDistribution(alice),
      unspentTokenInRecipient: bob,
      misc: ""
    });

    // Execute
    vm.prank(alice);
    (uint256 _returnAmountIn, uint256 _returnAmountOut) = adapter.buyOrderSwap(_params);

    // Assertions
    assertEq(tokenIn.balanceOf(alice), 0, "Token in not taken from alice");
    assertEq(tokenIn.balanceOf(bob), _maxAmountIn - _amountUsed, "Token in not sent to bob");
    assertEq(tokenIn.balanceOf(address(swapper)), _amountUsed, "Token in not sent to swapper");
    assertEq(address(swapper).balance, 0, "Token out not taken from swapper");
    assertEq(alice.balance, _amountOut, "Token out not sent to alice");
    assertEq(_returnAmountIn, _amountUsed, "Invalid returned value for amount in");
    assertEq(_returnAmountOut, _amountOut, "Invalid return value for amount out");
  }
}

contract TargetSwapper {
  function swap(address _tokenIn, uint256 _amountIn, address _tokenOut, uint256 _amountOut) external payable {
    if (_tokenIn == address(0)) {
      require(_amountIn == msg.value, "Invalid param");
    } else {
      MockERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
    }
    if (_tokenOut == address(0)) {
      payable(msg.sender).transfer(_amountOut);
    } else {
      MockERC20(_tokenOut).transfer(msg.sender, _amountOut);
    }
  }

  function swapAndReturnUnspent(
    address _tokenIn,
    uint256 _amountInReceived,
    uint256 _amountInReturned,
    address _tokenOut,
    uint256 _amountOut
  )
    external
    payable
  {
    if (_tokenIn == address(0)) {
      require(_amountInReceived == msg.value, "Invalid param");
      payable(msg.sender).transfer(_amountInReturned);
    } else {
      MockERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountInReceived);
      MockERC20(_tokenIn).transfer(msg.sender, _amountInReturned);
    }
    if (_tokenOut == address(0)) {
      payable(msg.sender).transfer(_amountOut);
    } else {
      MockERC20(_tokenOut).transfer(msg.sender, _amountOut);
    }
  }
}
