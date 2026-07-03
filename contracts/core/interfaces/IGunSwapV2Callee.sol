pragma solidity >=0.5.0;

interface IGunSwapV2Callee {
    function gunswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
