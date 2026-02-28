// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/ERC721.sol";
import {Ownable} from "openzeppelin-contracts@5.4.0/access/Ownable.sol";

/// @title Foundry NFT - Mintable ERC721 with fixed price
/// @author Foundry
/// @notice Users can mint NFTs by paying 0.01 ether; owner can withdraw proceeds
/// @dev Extends OpenZeppelin ERC721 and Ownable
contract FoundryNFT is ERC721, Ownable {
    // -------------------------------------------------------------------------
    // State variables
    // -------------------------------------------------------------------------

    uint256 public totalSupply;
    uint256 public constant MINT_PRICE = 0.01 ether;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error InsufficientPayment();
    error WithdrawFailed();

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() ERC721("FoundryNFT", "FNFT") Ownable(msg.sender) {}

    // -------------------------------------------------------------------------
    // External functions (payable first, then non-payable)
    // -------------------------------------------------------------------------

    /// @notice Mint a new NFT by paying MINT_PRICE
    /// @dev Increments totalSupply and mints to msg.sender
    function mint() external payable {
        if (msg.value < MINT_PRICE) revert InsufficientPayment();
        totalSupply++;
        _mint(msg.sender, totalSupply);
    }

    /// @notice Withdraw all contract balance to owner
    /// @dev Only callable by owner; reverts if transfer fails
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool ok,) = owner().call{value: balance}("");
        if (!ok) revert WithdrawFailed();
    }
}
