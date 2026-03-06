// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title DataContract
/// @notice Demonstrates the Data Contract pattern (separating state from logic).
contract DataContract {
    address public logicContract;
    uint256 public data;

    error Unauthorized();

    modifier onlyLogic() {
        if (msg.sender != logicContract) revert Unauthorized();
        _;
    }

    constructor() {
        logicContract = msg.sender;
    }

    function setLogicContract(address _logicContract) external {
        if (msg.sender != logicContract && logicContract != address(0)) revert Unauthorized();
        logicContract = _logicContract;
    }

    function setData(uint256 _data) external onlyLogic {
        data = _data;
    }
}

/// @title LogicContract
/// @notice Demonstrates the Logic Contract pattern.
contract LogicContract {
    DataContract public dataContract;

    constructor(address _dataContract) {
        dataContract = DataContract(_dataContract);
    }

    function processAndSave(uint256 input) external {
        // Perform some logic
        uint256 processed = input * 2;
        dataContract.setData(processed);
    }
}
