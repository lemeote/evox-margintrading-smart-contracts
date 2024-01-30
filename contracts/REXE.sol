// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract REXE is ERC20 {
    constructor(address initialOwner)
        ERC20("REXE", "REXE")
    {
        _mint(initialOwner, 1000000000000 * 10 ** decimals());
    }


function mint(address guy, uint256 wad) public {
    _mint(guy, wad);
}

}
