// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title EscrowJudge
/// @notice Demonstrates the Judge pattern (Access Control) / Access restriction.
contract EscrowJudge {
    address public buyer;
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

    constructor(address _seller, address _judge) {
        buyer = msg.sender;
        seller = _seller;
        judge = _judge;
        state = State.AwaitingPayment;
    }

    function deposit() external payable {
        if (msg.sender != buyer) revert Unauthorized();
        if (state != State.AwaitingPayment) revert InvalidState();
        amount += msg.value;
        state = State.AwaitingDelivery;
    }

    function confirmDelivery() external {
        if (msg.sender != buyer) revert Unauthorized();
        if (state != State.AwaitingDelivery) revert InvalidState();

        state = State.Completed;
        _transfer(seller, amount);
    }

    function raiseDispute() external {
        if (msg.sender != buyer && msg.sender != seller) revert Unauthorized();
        if (state != State.AwaitingDelivery) revert InvalidState();
        state = State.Disputed;
    }

    function resolveDispute(bool refundBuyer) external {
        if (msg.sender != judge) revert Unauthorized();
        if (state != State.Disputed) revert InvalidState();

        state = State.Completed;
        if (refundBuyer) {
            _transfer(buyer, amount);
        } else {
            _transfer(seller, amount);
        }
    }

    function _transfer(address to, uint256 amt) internal {
        (bool ok,) = to.call{value: amt}("");
        if (!ok) revert TransferFailed();
    }
}

/// @title EmbeddedPermission
/// @notice Demonstrates Embedded Permission (Meta-tx / Off-chain signature).
contract EmbeddedPermission {
    mapping(address => uint256) public nonces;

    event Executed(address indexed user, string action);
    error InvalidSignature();

    function executeWithSignature(address user, string calldata action, uint8 v, bytes32 r, bytes32 s) external {
        bytes32 messageHash = keccak256(abi.encodePacked(user, action, nonces[user]));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        address signer = ecrecover(ethSignedMessageHash, v, r, s);
        if (signer != user) revert InvalidSignature();

        nonces[user]++;
        emit Executed(user, action);
    }
}

/// @title DynamicBinding
/// @notice Demonstrates Dynamic Binding pattern for upgradability/swappable logic.
contract DynamicBinding {
    address public logicDelegate;
    address public owner;

    error Unauthorized();

    constructor(address _logic) {
        owner = msg.sender;
        logicDelegate = _logic;
    }

    function updateLogic(address _newLogic) external {
        if (msg.sender != owner) revert Unauthorized();
        logicDelegate = _newLogic;
    }

    fallback() external payable {
        address target = logicDelegate;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}
