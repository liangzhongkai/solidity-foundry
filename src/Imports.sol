pragma solidity 0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract MyERC20 is ERC20 {
    constructor() ERC20("MyERC20", "MYE", 18) {
        _mint(msg.sender, 1000000000000000000000000);
    }
}

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract TestOwnable is Ownable {
    constructor() Ownable(msg.sender) {}
}
