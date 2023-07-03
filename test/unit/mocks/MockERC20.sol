// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
  constructor() ERC20("TEST", "test") { }

  function mint(address _to, uint256 _amount) external {
    _mint(_to, _amount);
  }

  function burn(address _to, uint256 _amount) public virtual {
    _burn(_to, _amount);
  }
}
