// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IUniswapV3Pool} from "../interfaces/uni-v3/IUniswapV3Pool.sol";
import {BitMath} from "./BitMath.sol";

library TickLiquidity {
    function position(int24 tick)
        internal
        pure
        returns (int16 wordPos, uint8 bitPos)
    {
        wordPos = int16(tick >> 8);
        bitPos = uint8(tick % 256);
    }

    function nextInitializedTickWithinOneWord(
        IUniswapV3Pool pool,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            // all the 1s at or to the right of the current bitPos
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = pool.tickBitmap(wordPos) & mask;

            // if there are no initialized ticks to the right of or at the current tick, return rightmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed
                        - int24(bitPos - BitMath.mostSignificantBit(masked)))
                    * tickSpacing
                : (compressed - int24(bitPos)) * tickSpacing;
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            // all the 1s at or to the left of the bitPos
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = pool.tickBitmap(wordPos) & mask;

            // if there are no initialized ticks to the left of the current tick, return leftmost in the word
            initialized = masked != 0;
            // overflow/underflow is possible, but prevented externally by limiting both tickSpacing and tick
            next = initialized
                ? (compressed
                        + 1
                        + int24(BitMath.leastSignificantBit(masked) - bitPos))
                    * tickSpacing
                : (compressed + 1 + int24(type(uint8).max - bitPos))
                    * tickSpacing;
        }
    }

    function findNextInitializedTickAbove(
        IUniswapV3Pool pool,
        int24 compressed,
        int24 tickSpacing
    ) internal view returns (int24 tickLo, int24 tickHi, uint256 liquidity) {
        int16 wordPos = int16(compressed >> 8);
        uint8 bitPos = uint8(int8(compressed % 256));

        // Mask for bits above current position in same word
        uint256 mask = ~((1 << bitPos) - 1) << 1;
        uint256 word = pool.tickBitmap(wordPos) & mask;

        if (word != 0) {
            uint8 nextBit = BitMath.leastSignificantBit(word);
            int24 nextCompressed =
                (int24(wordPos) << 8) + int24(uint24(nextBit));
            tickLo = nextCompressed * tickSpacing;
            liquidity = pool.ticks(tickLo).liquidityGross;
            tickHi = findTickHi(pool, nextCompressed, tickSpacing);
        } else {
            for (int16 i = wordPos + 1; i <= wordPos + 256; i++) {
                word = pool.tickBitmap(i);
                if (word != 0) {
                    uint8 nextBit = BitMath.leastSignificantBit(word);
                    int24 nextCompressed =
                        (int24(i) << 8) + int24(uint24(nextBit));
                    tickLo = nextCompressed * tickSpacing;
                    liquidity = pool.ticks(tickLo).liquidityGross;
                    tickHi = findTickHi(pool, nextCompressed, tickSpacing);
                    break;
                }
            }
        }
    }

    function findNextInitializedTickBelow(
        IUniswapV3Pool pool,
        int24 compressed,
        int24 tickSpacing
    ) internal view returns (int24 tickLo, int24 tickHi, uint256 liquidity) {
        int16 wordPos = int16(compressed >> 8);
        uint8 bitPos = uint8(int8(compressed % 256));

        // Mask for bits at or below current position
        uint256 mask = (1 << (bitPos + 1)) - 1;
        uint256 word = pool.tickBitmap(wordPos) & mask;

        if (word != 0) {
            uint8 nextBit = BitMath.mostSignificantBit(word);
            int24 nextCompressed =
                (int24(wordPos) << 8) + int24(uint24(nextBit));
            tickHi = nextCompressed * tickSpacing;
            liquidity = pool.ticks(tickLo).liquidityGross;
            tickLo = findTickLo(pool, nextCompressed, tickSpacing);
        } else {
            for (int16 i = wordPos - 1; i >= wordPos - 256; i--) {
                word = pool.tickBitmap(i);
                if (word != 0) {
                    uint8 nextBit = BitMath.mostSignificantBit(word);
                    int24 nextCompressed =
                        (int24(i) << 8) + int24(uint24(nextBit));
                    tickHi = nextCompressed * tickSpacing;
                    liquidity = pool.ticks(tickLo).liquidityGross;
                    tickLo = findTickLo(pool, nextCompressed, tickSpacing);
                    break;
                }
            }
        }
    }

    function findTickHi(
        IUniswapV3Pool pool,
        int24 compressed,
        int24 tickSpacing
    ) internal view returns (int24) {
        int16 wordPos = int16((compressed + 1) >> 8);
        uint256 word = pool.tickBitmap(wordPos);
        if (word != 0) {
            return (int24(wordPos) << 8)
                + int24(uint24(BitMath.leastSignificantBit(word))) * tickSpacing;
        }
        return type(int24).max;
    }

    function findTickLo(
        IUniswapV3Pool pool,
        int24 compressed,
        int24 tickSpacing
    ) internal view returns (int24) {
        int16 wordPos = int16((compressed - 1) >> 8);
        uint256 word = pool.tickBitmap(wordPos);
        if (word != 0) {
            return (int24(wordPos) << 8)
                + int24(uint24(BitMath.mostSignificantBit(word))) * tickSpacing;
        }
        return type(int24).min;
    }
}
