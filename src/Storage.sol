// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract Storage {
    uint256 number;

    /// @dev Fix: Added event (Mistake #13)
    event ValueStored(uint256 oldValue, uint256 newValue);

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function store(uint256 num) public {
        emit ValueStored(number, num);
        number = num;
    }

    /**
     * @dev Return value
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256) {
        return number;
    }
}
