// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "./IERC20.sol";

library SafeTransfer {
    function safeTransfer(IERC20 token, address dst, uint256 amt) internal {
        (bool ok, bytes memory data) =
            address(token).call(abi.encodeCall(IERC20.transfer, (dst, amt)));

        require(ok, "call failed");

        if (data.length > 0) {
            require(abi.decode(data, (bool)), "transfer failed");
        }
    }

    function safeTransferFrom(
        IERC20 token,
        address src,
        address dst,
        uint256 amt
    ) internal {
        (bool ok, bytes memory data) = address(token)
            .call(abi.encodeCall(IERC20.transferFrom, (src, dst, amt)));

        require(ok, "call failed");

        if (data.length > 0) {
            require(abi.decode(data, (bool)), "transfer failed");
        }
    }
}
