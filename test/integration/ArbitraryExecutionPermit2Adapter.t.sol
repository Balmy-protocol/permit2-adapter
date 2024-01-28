// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC4626, IERC20 } from "@openzeppelin/contracts-4.8.0/interfaces/IERC4626.sol";
import { PRBTest } from "@prb/test/PRBTest.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { IDCAHub } from "./external/IDCAHub.sol";
import {
  UniversalPermit2Adapter, IPermit2, IArbitraryExecutionPermit2Adapter
} from "../../src/UniversalPermit2Adapter.sol";
import { Utils } from "../Utils.sol";

contract ArbitraryExecutionPermit2AdapterTest is PRBTest, StdCheats {
  IPermit2 internal constant PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
  address internal constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
  IERC20 internal constant USDC = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
  IERC4626 internal constant EXACTLY_USDC_VAULT = IERC4626(0xe9A15d436390BEB7D9eb312546DE3Fb01b1468EA);
  IDCAHub internal constant DCA_HUB = IDCAHub(0xA5AdC5484f9997fBF7D405b9AA62A7d88883C345);
  UniversalPermit2Adapter internal adapter;
  address internal alice = 0x9baA1c73dA6EaDE1D9Cd299b380181EFDDD38D0f;
  address internal bob = address(1);
  uint256 internal aliceKey = 0x3b226dfc360dd6c280a1e10cf039309949f0e1144cb24a233fd9512cd5c6edcd;
  uint256 internal amountToDeposit = 10_000e6; // 10k USDC

  function setUp() public virtual {
    vm.createSelectFork({ urlOrAlias: "optimism", blockNumber: 106_238_587 });

    // Alice gives full approval to Permit2
    vm.prank(alice);
    USDC.approve(address(PERMIT2), type(uint256).max);

    // Give alice the necessary funds
    deal(address(USDC), alice, amountToDeposit);

    // We are using the universal adapter to test arbitrary execution so that we can verify the full integration
    adapter = new UniversalPermit2Adapter(PERMIT2);
  }

  function testFork_executeWithPermit_DepositIntoExactly() public {
    // Prepare permit
    IArbitraryExecutionPermit2Adapter.SinglePermit memory _permit = Utils.buildSignedPermit(
      address(USDC), amountToDeposit, 0, type(uint256).max, address(adapter), aliceKey, PERMIT2.DOMAIN_SEPARATOR()
    );

    // Execute
    vm.prank(alice);
    (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithPermit(
      _permit,
      Utils.buildAllowanceTargets(address(EXACTLY_USDC_VAULT), address(USDC)),
      Utils.buildContractCalls(
        address(EXACTLY_USDC_VAULT),
        abi.encodeWithSelector(EXACTLY_USDC_VAULT.deposit.selector, amountToDeposit, address(adapter)),
        0
      ),
      Utils.buildTransferOut(address(EXACTLY_USDC_VAULT), Utils.buildDistribution(alice, 5000, bob)),
      type(uint256).max
    );

    // Assertions
    assertEq(_executionResults.length, 1);
    assertEq(_tokenBalances.length, 1);
    uint256 _shares = abi.decode(_executionResults[0], (uint256));
    assertEq(_shares, _tokenBalances[0]);

    // Shares were distributed correctly
    assertEq(EXACTLY_USDC_VAULT.balanceOf(address(adapter)), 0);
    assertEq(EXACTLY_USDC_VAULT.balanceOf(alice), _shares / 2);
    assertEq(EXACTLY_USDC_VAULT.balanceOf(bob), _shares - _shares / 2);
  }

  function testFork_executeWithPermit_DepositIntoMeanFinance() public {
    // Prepare permit
    IArbitraryExecutionPermit2Adapter.SinglePermit memory _permit = Utils.buildSignedPermit(
      address(USDC), amountToDeposit, 1, type(uint256).max, address(adapter), aliceKey, PERMIT2.DOMAIN_SEPARATOR()
    );

    // Execute
    vm.prank(alice);
    (bytes[] memory _executionResults, uint256[] memory _tokenBalances) = adapter.executeWithPermit(
      _permit,
      Utils.buildAllowanceTargets(address(DCA_HUB), address(USDC)),
      Utils.buildContractCalls(
        address(DCA_HUB),
        abi.encodeWithSelector(
          DCA_HUB.deposit.selector,
          address(USDC),
          DAI,
          amountToDeposit,
          10,
          1 days,
          alice,
          new IDCAHub.PermissionSet[](0)
        ),
        0
      ),
      Utils.buildEmptyTransferOut(),
      type(uint256).max
    );

    // Assertions
    assertEq(_executionResults.length, 1);
    assertEq(_tokenBalances.length, 0);
    uint256 _positionId = abi.decode(_executionResults[0], (uint256));
    IDCAHub.UserPosition memory _position = DCA_HUB.userPosition(_positionId);
    assertEq(_position.from, address(USDC));
    assertEq(_position.to, DAI);
    assertEq(_position.swapInterval, 1 days);
    assertEq(_position.swapsExecuted, 0);
    assertEq(_position.swapped, 0);
    assertEq(_position.swapsLeft, 10);
    assertEq(_position.remaining, amountToDeposit);
    assertEq(_position.rate, amountToDeposit / 10);
  }
}
