// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {EIP712} from "openzeppelin-contracts@5.4.0/utils/cryptography/EIP712.sol";

interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}

/// @title EscrowJudge
/// @notice Demonstrates the Judge pattern (Access Control) / Access restriction.
contract EscrowJudge {
    address public immutable buyer;
    address public seller;
    address public judge;
    uint256 public amount;

    enum State {
        AwaitingPayment,
        AwaitingDelivery,
        Completed,
        Disputed
    }
    State public state;

    error InvalidState();
    error Unauthorized();
    error TransferFailed();
    error ZeroAddress();
    error AmountZero();

    constructor(address seller_, address judge_) {
        if (seller_ == address(0) || judge_ == address(0)) revert ZeroAddress();

        buyer = msg.sender;
        seller = seller_;
        judge = judge_;
        state = State.AwaitingPayment;
    }

    function deposit() external payable {
        if (msg.sender != buyer) revert Unauthorized();
        if (state != State.AwaitingPayment) revert InvalidState();
        if (msg.value == 0) revert AmountZero();

        amount += msg.value;
        state = State.AwaitingDelivery;
    }

    function confirmDelivery() external {
        if (msg.sender != buyer) revert Unauthorized();
        if (state != State.AwaitingDelivery) revert InvalidState();

        uint256 payout = amount;
        amount = 0;
        state = State.Completed;
        _transfer(seller, payout);
    }

    function raiseDispute() external {
        if (msg.sender != buyer && msg.sender != seller) revert Unauthorized();
        if (state != State.AwaitingDelivery) revert InvalidState();

        state = State.Disputed;
    }

    function resolveDispute(bool refundBuyer) external {
        if (msg.sender != judge) revert Unauthorized();
        if (state != State.Disputed) revert InvalidState();

        uint256 payout = amount;
        amount = 0;
        state = State.Completed;

        if (refundBuyer) {
            _transfer(buyer, payout);
            return;
        }

        _transfer(seller, payout);
    }

    function _transfer(address to, uint256 amt) internal {
        (bool ok,) = to.call{value: amt}("");
        if (!ok) revert TransferFailed();
    }
}

/// @title EmbeddedPermission
/// @notice Modern embedded permissions using EIP-712 typed data and ERC-1271-compatible signatures.
contract EmbeddedPermission is EIP712 {
    bytes4 private constant ERC1271_MAGICVALUE = 0x1626ba7e;
    bytes32 private constant PERMISSION_TYPEHASH =
        keccak256("Permission(address user,bytes32 actionHash,uint256 nonce,uint256 deadline)");

    mapping(address => uint256) public nonces;

    event Executed(address indexed user, bytes32 indexed actionHash, uint256 indexed nonce);

    error InvalidSignature();
    error SignatureExpired(uint256 currentTime, uint256 deadline);

    constructor() EIP712("EmbeddedPermission", "1") {}

    function permissionDigest(address user, bytes32 actionHash, uint256 nonce, uint256 deadline)
        public
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(PERMISSION_TYPEHASH, user, actionHash, nonce, deadline)));
    }

    function executeWithSignature(address user, bytes32 actionHash, uint256 deadline, bytes calldata signature)
        external
    {
        if (block.timestamp > deadline) revert SignatureExpired(block.timestamp, deadline);

        uint256 nonce = nonces[user];
        bytes32 digest = permissionDigest(user, actionHash, nonce, deadline);
        if (!_isValidSignatureNow(user, digest, signature)) revert InvalidSignature();

        nonces[user] = nonce + 1;
        emit Executed(user, actionHash, nonce);
    }

    function _isValidSignatureNow(address signer, bytes32 digest, bytes calldata signature)
        internal
        view
        returns (bool)
    {
        if (signer.code.length == 0) {
            if (signature.length != 65) {
                return false;
            }

            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := calldataload(signature.offset)
                s := calldataload(add(signature.offset, 32))
                v := byte(0, calldataload(add(signature.offset, 64)))
            }

            return ecrecover(digest, v, r, s) == signer;
        }

        try IERC1271(signer).isValidSignature(digest, signature) returns (bytes4 magicValue) {
            return magicValue == ERC1271_MAGICVALUE;
        } catch {
            return false;
        }
    }
}

/// @title DynamicBinding
/// @notice Modernized dynamic binding using EIP-1967-style storage slots for upgrades.
interface IERC1822ProxiableDemo {
    function proxiableUUID() external view returns (bytes32);
}

/// @notice Shared storage slots used by all three upgrade patterns in this teaching example.
/// The differences below are about where upgrade authority lives and whether the admin may hit fallback.
abstract contract ERC1967Slots {
    bytes32 internal constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed admin);

    error ZeroAddress();
    error UpgradeFailed();

    function _delegate(address target) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _upgradeToAndCall(address newImplementation, bytes memory initData) internal {
        if (newImplementation == address(0)) revert ZeroAddress();
        _setImplementation(newImplementation);

        if (initData.length != 0) {
            (bool ok,) = newImplementation.delegatecall(initData);
            if (!ok) revert UpgradeFailed();
        }
    }

    function _getAdmin() internal view returns (address admin_) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            admin_ := sload(slot)
        }
    }

    function _setAdmin(address admin_) internal {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, admin_)
        }

        emit AdminChanged(admin_);
    }

    function _getImplementation() internal view returns (address implementation_) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            implementation_ := sload(slot)
        }
    }

    function _setImplementation(address implementation_) internal {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, implementation_)
        }

        emit Upgraded(implementation_);
    }
}

contract DynamicBinding is ERC1967Slots {
    error Unauthorized();

    constructor(address admin_, address implementation_, bytes memory initData) payable {
        if (admin_ == address(0) || implementation_ == address(0)) revert ZeroAddress();

        _setAdmin(admin_);
        _upgradeToAndCall(implementation_, initData);
    }

    function admin() external view returns (address admin_) {
        admin_ = _getAdmin();
    }

    function implementation() external view returns (address implementation_) {
        implementation_ = _getImplementation();
    }

    function upgradeTo(address newImplementation, bytes calldata initData) external {
        if (msg.sender != _getAdmin()) revert Unauthorized();
        _upgradeToAndCall(newImplementation, initData);
    }

    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {
        _delegate(_getImplementation());
    }
}

/// @title TransparentBinding
/// @notice Transparent proxy variant where the admin can upgrade but cannot fallback into implementation logic.
contract TransparentBinding is ERC1967Slots {
    error Unauthorized();
    error AdminCannotFallback();

    constructor(address admin_, address implementation_, bytes memory initData) payable {
        if (admin_ == address(0) || implementation_ == address(0)) revert ZeroAddress();

        _setAdmin(admin_);
        _upgradeToAndCall(implementation_, initData);
    }

    function admin() external view returns (address admin_) {
        admin_ = _getAdmin();
    }

    function implementation() external view returns (address implementation_) {
        implementation_ = _getImplementation();
    }

    function upgradeTo(address newImplementation, bytes calldata initData) external {
        if (msg.sender != _getAdmin()) revert Unauthorized();
        _upgradeToAndCall(newImplementation, initData);
    }

    // Transparency rule: the admin can manage upgrades, but must not execute user logic through the proxy.
    fallback() external payable {
        if (msg.sender == _getAdmin()) revert AdminCannotFallback();
        _delegate(_getImplementation());
    }

    receive() external payable {
        if (msg.sender == _getAdmin()) revert AdminCannotFallback();
        _delegate(_getImplementation());
    }
}

/// @title UUPSBinding
/// @notice Minimal ERC1967 proxy shell used by UUPS implementations.
/// Unlike DynamicBinding/TransparentBinding, this proxy has no external upgrade function.
contract UUPSBinding is ERC1967Slots {
    constructor(address implementation_, bytes memory initData) payable {
        if (implementation_ == address(0)) revert ZeroAddress();
        _upgradeToAndCall(implementation_, initData);
    }

    function implementation() external view returns (address implementation_) {
        implementation_ = _getImplementation();
    }

    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {
        _delegate(_getImplementation());
    }
}

/// @title UUPSUpgradeableDemo
/// @notice Minimal UUPS implementation mixin. The proxy is dumb; the implementation owns the upgrade path.
abstract contract UUPSUpgradeableDemo is ERC1967Slots, IERC1822ProxiableDemo {
    address private immutable SELF = address(this);

    error UUPSOnlyProxy();
    error UUPSNotDelegated();
    error UUPSUnsupportedUUID(bytes32 slot);
    error InvalidUUPSImplementation();

    modifier onlyProxy() {
        if (address(this) == SELF || _getImplementation() != SELF) revert UUPSOnlyProxy();
        _;
    }

    modifier notDelegated() {
        if (address(this) != SELF) revert UUPSNotDelegated();
        _;
    }

    function proxiableUUID() external view notDelegated returns (bytes32) {
        return IMPLEMENTATION_SLOT;
    }

    // In UUPS, callers reach this function through the proxy, so storage writes still land in the proxy.
    function upgradeTo(address newImplementation, bytes calldata initData) external onlyProxy {
        _authorizeUpgrade(msg.sender);

        try IERC1822ProxiableDemo(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != IMPLEMENTATION_SLOT) revert UUPSUnsupportedUUID(slot);
        } catch {
            revert InvalidUUPSImplementation();
        }

        _upgradeToAndCall(newImplementation, initData);
    }

    function _authorizeUpgrade(address caller) internal view virtual;
}

/*
Upgrade pattern comparison in this file:

1. DynamicBinding
   - Upgrade entrypoint lives on the proxy itself.
   - Admin stored in the proxy decides upgrades.
   - Admin may still call implementation logic through fallback.

2. TransparentBinding
   - Upgrade entrypoint also lives on the proxy itself.
   - Admin stored in the proxy decides upgrades.
   - Admin is blocked from fallback, so admin actions and user actions stay separated.

3. UUPSBinding + UUPSUpgradeableDemo
   - Proxy is only a thin delegatecall shell.
   - Upgrade entrypoint lives in the implementation and is reached via delegatecall.
   - Upgrade authorization is defined by implementation code, not by a proxy-only admin function.
*/
