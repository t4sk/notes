// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "../src/IERC20.sol";

// MCD_LITE_PSM_USDC_A
address constant LITE_PSM = 0xf6e72Db5454dd049d0788e411b06CfAF16853042;

interface IDssLitePsm {
    function gem() external view returns (address);
    function dai() external view returns (address);
    // Address where gem is stored
    function pocket() external view returns (address);
    // Fee for selling gem 1e18 = 100%
    function tin() external view returns (uint256);
    // Fee for buying gem 1e18 = 100%
    function tout() external view returns (uint256);

    function sellGem(address usr, uint256 gemAmt) external returns (uint256 daiOutWad);
    function buyGem(address usr, uint256 gemAmt) external returns (uint256 daiInWad);
}

/*
FORK_URL=
forge test --fork-url $FORK_URL --match-path test/LitePsm.t.sol -vvv
*/
contract LitePsmTest is Test {
    IDssLitePsm constant psm = IDssLitePsm(LITE_PSM);
    IERC20 dai;
    IERC20 gem;

    function setUp() public {
        dai = IERC20(psm.dai());
        gem = IERC20(psm.gem());
        console.log("DAI:", address(dai));
        console.log("Gem:", address(gem));

        // Gem is stored in pocket
        console.log("Gem pocket: %e", gem.balanceOf(psm.pocket()));
    }

    function test_sell_gem() public {
        uint256 gemAmt = 1e6 * 1e6;
        deal(address(gem), address(this), gemAmt);
        gem.approve(address(psm), type(uint256).max);

        console.log("tin: %e", psm.tin());

        psm.sellGem(address(this), gemAmt);

        console.log("Gem out: %e", gemAmt);
        console.log("DAI in: %e", dai.balanceOf(address(this)));
    }

    function test_buy_gem() public {
        uint256 gemAmt = 1e6 * 1e6;
        uint256 daiAmt = gemAmt * 1e12 * (1e18 + psm.tout()) / 1e18;
        deal(address(dai), address(this), daiAmt);
        dai.approve(address(psm), type(uint256).max);

        console.log("tout: %e", psm.tout());

        psm.buyGem(address(this), gemAmt);

        console.log("Gem in: %e", gem.balanceOf(address(this)));
        console.log("DAI out: %e", daiAmt);
    }
}
