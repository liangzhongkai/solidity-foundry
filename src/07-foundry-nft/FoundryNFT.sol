// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract FoundryNFT is ERC721, Ownable {
    uint256 public totalSupply = 0;
    uint256 public constant MINT_PRICE = 0.01 ether;

    constructor() ERC721("FoundryNFT", "FNFT") Ownable(msg.sender) {}

    function mint() external payable {
        require(msg.value >= MINT_PRICE, "insufficient payment");
        totalSupply++;
        _mint(msg.sender, totalSupply);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool ok,) = owner().call{value: balance}("");
        require(ok, "withdraw failed");
    }
}
