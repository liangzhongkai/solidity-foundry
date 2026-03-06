// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std@1.14.0/Test.sol";
import {PublisherSubscriber} from "../../../src/10-design-patterns/efficiency/PublisherSubscriber.sol";

contract PublisherSubscriberTest is Test {
    PublisherSubscriber internal pubsub;
    address internal user1 = address(0x1);
    address internal user2 = address(0x2);

    function setUp() public {
        pubsub = new PublisherSubscriber();
    }

    function test_Subscribe() public {
        vm.prank(user1);
        pubsub.subscribe("Topic1");
    }

    function test_SubscribeTwiceReverts() public {
        vm.prank(user1);
        pubsub.subscribe("Topic1");

        vm.prank(user1);
        vm.expectRevert(PublisherSubscriber.AlreadySubscribed.selector);
        pubsub.subscribe("Topic1");
    }

    function test_Unsubscribe() public {
        vm.prank(user1);
        pubsub.subscribe("Topic1");

        vm.prank(user1);
        pubsub.unsubscribe("Topic1");
    }

    function test_UnsubscribeNotSubscribedReverts() public {
        vm.prank(user1);
        vm.expectRevert(PublisherSubscriber.NotSubscribed.selector);
        pubsub.unsubscribe("Topic1");
    }

    function test_Publish() public {
        vm.prank(user1);
        pubsub.subscribe("Topic1");

        // We can't easily assert event emission without vm.expectEmit, but we can call it to ensure no reverts
        pubsub.publish("Topic1", "Hello World");
    }
}
