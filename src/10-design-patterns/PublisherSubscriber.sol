// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title PublisherSubscriber
/// @notice Demonstrates the Publisher-Subscriber efficiency pattern.
/// By emitting events instead of executing expensive on-chain calls to multiple contracts,
/// it saves significant gas while still notifying interested parties.
contract PublisherSubscriber {
    mapping(bytes32 => address[]) public subscribers;

    event Subscribed(bytes32 indexed topic, address indexed subscriber);
    event Unsubscribed(bytes32 indexed topic, address indexed subscriber);
    event Published(bytes32 indexed topic, string message);

    error AlreadySubscribed();
    error NotSubscribed();

    function subscribe(bytes32 topic) external {
        address[] storage subs = subscribers[topic];
        for (uint256 i = 0; i < subs.length; i++) {
            if (subs[i] == msg.sender) revert AlreadySubscribed();
        }
        subs.push(msg.sender);
        emit Subscribed(topic, msg.sender);
    }

    function unsubscribe(bytes32 topic) external {
        address[] storage subs = subscribers[topic];
        bool found = false;
        for (uint256 i = 0; i < subs.length; i++) {
            if (subs[i] == msg.sender) {
                subs[i] = subs[subs.length - 1];
                subs.pop();
                found = true;
                break;
            }
        }
        if (!found) revert NotSubscribed();
        emit Unsubscribed(topic, msg.sender);
    }

    function publish(bytes32 topic, string calldata message) external {
        // Efficiency Pattern: Emit an event for off-chain subscribers to listen to,
        // rather than iterating through an array and calling each subscriber on-chain.
        emit Published(topic, message);
    }
}
