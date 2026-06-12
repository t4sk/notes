// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";

/*
forge test --match-path Gas.t.sol -vvv
*/

/*
# 63 / 64 gas rule
External calls receive at most 63 / 64 of gas left in current contract
1 / 64 gas is kept in the current contract

A calls B
g0 = call to gasleft() somewhere in A
g1 = call to gasleft() somewhere in B
g' = Actual gas left immediately before call to B

  g'    63/64 g'
A |---->| B
|         |
g0        g1

# Gas used
dg = gas used between g0 and g1
   = gas used between g0 and g' + gas used between g' and g1
   = (g0 - g') + (63/64 * g' - g1)
   = g0 - 1/64 * g' - g1 >= 0

Therefore
   g0 - g1 >= 1/64 * g'

# Problem
- Refund of g0 - g1 over pays by 1/64 * g'
- g' can be large by sending large amount of gas

# Fix to overpaying refund
g1    <= 63/64 * g' <= g0
g1/63 <=  1/64 * g' <= g0/63

g0 - g1 - g1/63 >= g0 - g1 - g'/64 >= g0 - g1 - g0/63
                                   >= 0
Refund g0 - g1 - g1/63 = g0 - 64/63 * g1
*/

contract A {
    function f(address b) external returns (uint256, uint256, uint256) {
        uint256 gasStart = gasleft();
        (uint256 gasEnd, uint256 gasUsed) =
            B(payable(b)).g(msg.sender, gasStart);
        return (gasStart, gasEnd, gasUsed);
    }
}

contract B {
    receive() external payable {}

    function g(address receiver, uint256 gasStart)
        external
        returns (uint256, uint256)
    {
        uint256 gasNow = gasleft();

        // Gas refund
        uint256 gasUsed = gasStart - gasNow;

        // Fix
        // uint256 gasUsed = gasStart - gasNow * 64 / 63;

        (bool ok,) = receiver.call{value: gasUsed}("");
        require(ok, "send failed");

        return (gasNow, gasUsed);
    }
}

contract GasTest is Test {
    receive() external payable {
        console.log("gas refund: %e", msg.value);
    }

    function test() public {
        A a = new A();
        B b = new B();

        address(b).call{value: 1e18}("");

        (uint256 gs1, uint256 ge1, uint256 gasUsed1) = a.f{gas: 1e6}(address(b));

        // Run with large gas (gas to send must be <= block.gaslimit)
        console.log("block gas limit: %e", block.gaslimit);
        (uint256 gs2, uint256 ge2, uint256 gasUsed2) = a.f{gas: 1e9}(address(b));

        // Actual work in B is identical both times
        // but naive refund differs because g'/64 scales with gas supplied
        console.log("small gas refund: %e", gasUsed1);
        console.log("large gas refund: %e", gasUsed2);
        console.log("diff %e", gasUsed2 - gasUsed1);
    }
}
