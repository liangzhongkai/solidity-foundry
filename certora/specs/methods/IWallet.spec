methods {
    function owner() external returns (address) envfree;
    function withdraw(uint256) external;
    function setOwner(address) external;
}
