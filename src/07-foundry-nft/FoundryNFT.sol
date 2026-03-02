// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "openzeppelin-contracts@5.4.0/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts@5.4.0/access/Ownable.sol";

/// @title Foundry NFT - Mintable ERC721 with fixed price in ERC20
/// @author Foundry
/// @notice Users can mint NFTs by paying with a specific ERC20 token; owner can withdraw proceeds
/// @dev Extends OpenZeppelin ERC721 and Ownable
contract FoundryNFT is ERC721, Ownable {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // State variables
    // -------------------------------------------------------------------------

    uint256 public totalSupply;
    uint256 public constant MINT_PRICE = 10 * 10 ** 18; // 10 tokens (assuming 18 decimals)
    IERC20 public immutable paymentToken;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error InsufficientAllowance();
    error InsufficientBalance();

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @param _paymentToken The ERC20 token address used for payment
    constructor(address _paymentToken) ERC721("FoundryNFT", "FNFT") Ownable(msg.sender) {
        paymentToken = IERC20(_paymentToken);
    }

    // -------------------------------------------------------------------------
    // External functions
    // -------------------------------------------------------------------------

    /// @notice Mint a new NFT by paying MINT_PRICE in ERC20 tokens
    /// @dev Caller must approve this contract to spend MINT_PRICE tokens first
    function mint() external {
        if (paymentToken.balanceOf(msg.sender) < MINT_PRICE) revert InsufficientBalance();
        if (paymentToken.allowance(msg.sender, address(this)) < MINT_PRICE) revert InsufficientAllowance();

        paymentToken.safeTransferFrom(msg.sender, address(this), MINT_PRICE);

        totalSupply++;
        _mint(msg.sender, totalSupply);
    }

    /// @notice Withdraw all payment tokens to owner
    /// @dev Only callable by owner
    function withdraw() external onlyOwner {
        uint256 balance = paymentToken.balanceOf(address(this));
        if (balance > 0) {
            paymentToken.safeTransfer(owner(), balance);
        }
    }
}
