// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts@5.4.0/token/ERC20/utils/SafeERC20.sol";

/// @title CosmosERC20
/// @notice Wrapper deployed by the permissionless `deployERC20()` path.
contract CosmosERC20 is ERC20 {
    uint8 private immutable _decimals;

    constructor(address gravityAddress, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
        _mint(gravityAddress, 1e24);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

/// @title Gravity
/// @notice Simplified Gravity Bridge model for the May 2026 denom-mapping poisoning exploit.
/// @dev Reference: https://rekt.news/gravity-bridge-rekt
contract Gravity {
    using SafeERC20 for IERC20;

    address public immutable owner;
    address[] public validators;
    mapping(address => uint256) public validatorPower;
    uint256 public totalPower;

    /// @notice Cosmos denom string → Ethereum ERC20 address (poisoned during the exploit).
    mapping(string => address) public denomToErc20;

    /// @notice Reverse lookup used elsewhere in the real module, but omitted in the vulnerable path.
    mapping(address => string) public erc20ToDenom;

    /// @notice ETH-originated assets already held in bridge custody.
    mapping(address => bool) public isCustodyAsset;

    event ERC20DeployedEvent(
        string _cosmosDenom, address indexed _tokenContract, string _name, string _symbol, uint8 _decimals
    );

    event WithdrawBatch(address indexed token, address indexed destination, uint256 amount);

    error ZeroPower();
    error AlreadyRegistered();
    error UnknownDenom();
    error InvalidTokenContract();
    error CustodyAssetCollision();
    error DenomCollision();
    error UnauthorizedOwner();
    error UnauthorizedValidator();

    constructor(address[] memory validators_, uint256[] memory powers_) {
        owner = msg.sender;
        for (uint256 i = 0; i < validators_.length; i++) {
            validators.push(validators_[i]);
            validatorPower[validators_[i]] = powers_[i];
            totalPower += powers_[i];
        }
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert UnauthorizedOwner();
        _;
    }

    modifier onlyValidator() {
        if (validatorPower[msg.sender] == 0) revert UnauthorizedValidator();
        _;
    }

    function registerValidator(address validator, uint256 power) external onlyOwner {
        if (power == 0) revert ZeroPower();
        if (validatorPower[validator] != 0) revert AlreadyRegistered();
        validators.push(validator);
        validatorPower[validator] = power;
        totalPower += power;
    }

    /// @notice Registers real custody assets and their canonical Cosmos denoms at bridge init.
    function registerCustodyAsset(address token, string calldata cosmosDenom) external onlyOwner {
        if (isCustodyAsset[token]) revert AlreadyRegistered();
        isCustodyAsset[token] = true;
        denomToErc20[cosmosDenom] = token;
        erc20ToDenom[token] = cosmosDenom;
    }

    /// @notice Permissionless registration — `_cosmosDenom` is attacker-controlled with no validation.
    /// @dev Real contract: Gravity-Bridge/solidity/contracts/Gravity.sol
    function deployERC20(string calldata cosmosDenom, string calldata name_, string calldata symbol_, uint8 decimals_)
        external
        returns (address)
    {
        CosmosERC20 erc20 = new CosmosERC20(address(this), name_, symbol_, decimals_);
        emit ERC20DeployedEvent(cosmosDenom, address(erc20), name_, symbol_, decimals_);
        return address(erc20);
    }

    /// @notice Simulates `MsgERC20DeployedClaim` processing on Gravity chain.
    /// @dev Rejects mappings that would collide with already-registered custody assets.
    function handleErc20Deployed(
        string calldata cosmosDenom,
        address tokenContract,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_
    ) external {
        _handleErc20Deployed(cosmosDenom, tokenContract, name_, symbol_, decimals_);
    }

    /// @notice Compatibility alias for the patched handler.
    function handleErc20DeployedSecure(
        string calldata cosmosDenom,
        address tokenContract,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_
    ) external {
        _handleErc20Deployed(cosmosDenom, tokenContract, name_, symbol_, decimals_);
    }

    /// @notice Simulates `DenomToERC20Lookup` during batch construction.
    function denomToERC20Lookup(string calldata cosmosDenom) public view returns (address) {
        return denomToErc20[cosmosDenom];
    }

    /// @notice Validators sign withdrawal batches; bridge releases mapped ERC20 from custody.
    function submitWithdrawalBatch(string calldata cosmosDenom, address destination, uint256 amount)
        external
        onlyValidator
    {
        address token = denomToERC20Lookup(cosmosDenom);
        if (token == address(0)) revert UnknownDenom();
        IERC20(token).safeTransfer(destination, amount);
        emit WithdrawBatch(token, destination, amount);
    }

    function getDenomToErc20(string calldata denom) external view returns (address) {
        return denomToErc20[denom];
    }

    function _validateTokenContract(address tokenContract) internal pure {
        if (tokenContract == address(0)) revert InvalidTokenContract();
    }

    function _handleErc20Deployed(
        string calldata cosmosDenom,
        address tokenContract,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_
    ) internal {
        _validateTokenContract(tokenContract);
        // Metadata checks exist in production but are bypassable via predictable ibc-go values.
        name_;
        symbol_;
        decimals_;

        if (bytes(erc20ToDenom[tokenContract]).length > 0) revert CustodyAssetCollision();
        if (isCustodyAsset[tokenContract]) revert CustodyAssetCollision();

        address existing = denomToErc20[cosmosDenom];
        if (existing != address(0) && isCustodyAsset[existing]) revert DenomCollision();

        denomToErc20[cosmosDenom] = tokenContract;
        erc20ToDenom[tokenContract] = cosmosDenom;
    }
}
