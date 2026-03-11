import "helpers/helpers.spec";
import "methods/IWallet.spec";

rule withdrawOnlyOwner(env e, uint256 amount) {
    require nonpayable(e);

    address current = owner();
    address oldOwner = current;

    withdraw@withrevert(e, amount);

    // Only owner can succeed; non-owner always reverts. Owner may still revert if transfer fails.
    assert !lastReverted => e.msg.sender == current, "withdraw access control failed";
    assert owner() == oldOwner, "withdraw must not change owner";
}

rule setOwnerOnlyOwner(env e, address newOwner) {
    require nonpayable(e);

    address current = owner();

    setOwner@withrevert(e, newOwner);
    bool success = !lastReverted;

    assert success <=> (e.msg.sender == current && newOwner != 0), "setOwner authorization or zero-address check failed";
    assert success => owner() == newOwner, "owner not updated on successful setOwner";
}

rule failedSetOwnerPreservesOwner(env e, address newOwner) {
    require nonpayable(e);

    address oldOwner = owner();

    setOwner@withrevert(e, newOwner);

    assert lastReverted => owner() == oldOwner, "failed setOwner changed owner";
}

rule ownerChangesOnlyViaAuthorizedSetOwner(env e) {
    require nonpayable(e);

    address oldOwner = owner();

    method f;
    calldataarg args;
    f(e, args);

    address newOwner = owner();

    assert oldOwner != newOwner => (
        f.selector == sig:setOwner(address).selector &&
        e.msg.sender == oldOwner &&
        newOwner != 0
    ), "owner changed outside authorized setOwner flow";
}

invariant ownerIsNeverZero()
    owner() != 0
    {
        preserved constructor() with (env e) {
            require e.msg.sender != 0;
        }
    }
