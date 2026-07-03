// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IWithdrawDelay {
    enum State {
        Live,
        Stopped,
        Covered,
        Refilled
    }

    function auths(address usr) external view returns (bool);
    function allow(address usr) external;
    function deny(address usr) external;

    function token() external view returns (address);
    function stake() external view returns (address);
    function EPOCH() external view returns (uint256);
    function state() external view returns (State);
    function stopped() external view returns (bool);
    function counts(address usr) external view returns (uint256);
    function locks(address usr, uint256 i)
        external
        view
        returns (uint256 amt, uint256 exp);
    function keep() external view returns (uint256);
    function last() external view returns (uint256);
    function buckets(uint256 i) external view returns (uint256);
    function dumped() external view returns (uint256);

    function queue(uint256 amt) external returns (uint256 i);
    function unlock(uint256 i) external;

    function stop() external returns (uint256 amt);
    function cover(address dst) external;
    function refill() external;
    function recover(address token) external;
}
