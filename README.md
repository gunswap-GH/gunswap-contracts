# GunSwap V2 — Contracts

A [Uniswap V2](https://uniswap.org/docs) style automated market maker (AMM) for **BNB Smart Chain (BSC)** — constant-product pools, LP tokens, a TWAP price oracle, and `CREATE2` pair addresses.

## Layout

Core and Router are one Hardhat project that compiles both Solidity versions:

```
contracts/
  core/     — solc 0.5.16: GunSwapV2Factory, GunSwapV2Pair, GunSwapV2ERC20, interfaces/, libraries/
  router/   — solc 0.6.6: GunSwapV2Router01/02, GunSwapV2Migrator, libraries/, interfaces/
```

- **Factory** — deploys and registers pairs via `CREATE2` (salt = `keccak256(token0, token1)`, tokens sorted).
- **Pair** — one per token pair; the AMM and its own LP token. `mint` / `burn` / `swap` are low-level and `lock`-guarded.
- **ERC20** — LP token: minimal ERC-20 plus EIP-2612 `permit`.
- **Router02** — the user-facing entrypoint (add/remove liquidity, swaps). It never holds funds between calls.
- **Library** — off-chain math and `pairFor` (computes pair addresses without an external call).

## Build

Requires Node.js (tested on Node 20) and Yarn.

```
yarn            # install dependencies
yarn compile    # hardhat compile — core with 0.5.16, router with 0.6.6
yarn clean      # hardhat clean
```

Both compilers use optimizer `runs: 999999` and `evmVersion: istanbul`, pinned so bytecode and `CREATE2` pair addresses stay consistent.

## Deployment

Only two contracts need deploying:

1. `GunSwapV2Factory` — constructor: `feeToSetter`.
2. `GunSwapV2Router02` — constructor: factory address, WBNB address.

Pairs are created on demand by the factory. `GunSwapV2Library` is inlined into the router. WBNB is an existing external contract on BSC.

## License

GPL-3.0 — see [LICENSE](./LICENSE). Derived from Uniswap V2.
