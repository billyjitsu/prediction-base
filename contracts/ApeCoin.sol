// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleToken is ERC20 {

    constructor(
        string memory name,
        string memory symbol
      //  uint256 totalSupply_
    ) ERC20(name, symbol) {
       // _mint(msg.sender, totalSupply_);
    }

    //add a function to mint more tokens
    function mint() public {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }

}