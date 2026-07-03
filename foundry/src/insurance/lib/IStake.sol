// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IStake {
    enum State {
        Live,
        Stopped,
        Cover,
        Exit
    }

    function auths(address usr) external view returns (bool);
    function allow(address usr) external;
    function deny(address usr) external;

    function token() external view returns (address);
    function dur() external view returns (uint256);
    function dust() external view returns (uint256);
    function cov() external view returns (uint256);
    function state() external view returns (State);
    function stopped() external view returns (bool);
    function insuree() external view returns (address);
    function total() external view returns (uint256);
    function shares(address usr) external view returns (uint256);
    function last() external view returns (uint256);
    function exp() external view returns (uint256);
    function rate() external view returns (uint256);
    function acc() external view returns (uint256);
    function accs(address usr) external view returns (uint256);
    function rewards(address usr) external view returns (uint256);
    function nextRate() external view returns (uint256);
    function next() external view returns (uint256);
    function keep() external view returns (uint256);
    function topped() external view returns (uint256);
    function paid() external view returns (uint256);
    function pot() external view returns (uint256);
    function calc(address usr) external view returns (uint256);

    function deposit(uint256 amt) external;
    function withdraw(address usr, address dst, uint256 amt) external;
    function take() external returns (uint256 amt);
    function restake() external returns (uint256 amt);
    function exit() external returns (uint256 amt);
    function sync(address usr) external returns (uint256 amt);

    function inc(uint256 amt) external;
    function roll(uint256 rate) external;
    function refund() external returns (uint256 amt);

    function stop() external;
    function settle(State s) external;
    function cover(address dst, uint256 amt) external returns (uint256);
    function recover(address token) external;
}
