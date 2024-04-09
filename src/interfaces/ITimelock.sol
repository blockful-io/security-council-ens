// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ITimelock {
    event Claimed(address indexed owner, address indexed recipient, uint256 amount);
    event Locked(address indexed sender, address indexed recipient, uint256 amount);

    function claim(address recipient, uint256 amount) external;

    function claimableBalance(address owner) external view returns (uint256);

    function claimedAmounts(address) external view returns (uint256);

    function lock(address recipient, uint256 amount) external;

    function lockedAmounts(address) external view returns (uint256);

    function token() external view returns (address);

    function unlockBegin() external view returns (uint256);

    function unlockCliff() external view returns (uint256);

    function unlockEnd() external view returns (uint256);
}
