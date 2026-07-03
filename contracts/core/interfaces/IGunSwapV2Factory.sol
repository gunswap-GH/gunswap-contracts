pragma solidity >=0.5.0;

interface IGunSwapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function pendingFeeToSetter() external view returns (address);

    function feeVault() external view returns (address);
    function isFeeAdmin(address) external view returns (bool);
    function defaultSwapFee() external view returns (uint);
    function swapFeeOverride(address pair) external view returns (uint);
    function swapFee(address pair) external view returns (uint);
    function swapFeeInfo(address pair) external view returns (uint fee, address vault);
    function pairCodeHash() external pure returns (bytes32);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function acceptFeeToSetter() external;
    function setFeeVault(address) external;

    function setFeeAdmin(address, bool) external;
    function setDefaultSwapFee(uint) external;
    function setSwapFee(address pair, uint fee) external;
}
