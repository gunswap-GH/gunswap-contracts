pragma solidity =0.5.16;

import './interfaces/IGunSwapV2Factory.sol';
import './GunSwapV2Pair.sol';

contract GunSwapV2Factory is IGunSwapV2Factory {
    // all fees are denominated in 1/10000 (basis points): 30 = 0.30%, 50 = 0.50%
    uint public constant MAX_SWAP_FEE = 100; // hard cap of 1%, can never be exceeded even by an admin

    address public feeTo;
    address public feeToSetter;
    address public pendingFeeToSetter;                // two-step ownership transfer: must be accepted by the nominee

    // fee vault that GunSwapV2Pair.swap siphons the swap fee to on every trade.
    // address(0) = no siphon: the pair falls back to standard V2 behaviour (fee stays in the pool).
    address public feeVault;

    // operational admins allowed to change swap fees; multiple, each its own address so every fee
    // change is attributable on-chain to a specific operator. Owner appoints/revokes via setFeeAdmin.
    mapping(address => bool) public isFeeAdmin;
    uint public defaultSwapFee = 30;                  // 0.30% default applied to every pair without an override
    mapping(address => uint) public swapFeeOverride;  // per-pair fee; 0 means "fall back to defaultSwapFee"

    mapping(address => mapping(address => address)) public getPair;
    mapping(address => bool) public isPair;           // true for pairs created by THIS factory (guards setSwapFee)
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    event FeeToChanged(address indexed previousFeeTo, address indexed newFeeTo);
    event FeeToSetterTransferStarted(address indexed previousFeeToSetter, address indexed pendingFeeToSetter);
    event FeeToSetterTransferred(address indexed previousFeeToSetter, address indexed newFeeToSetter);
    event FeeVaultChanged(address indexed previousVault, address indexed newVault);
    event FeeAdminChanged(address indexed admin, bool allowed);
    event DefaultSwapFeeChanged(uint previousFee, uint newFee);
    event SwapFeeChanged(address indexed pair, uint previousFee, uint newFee);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    // feeToSetter is the owner role. It manages WHO the fee admin is; the feeAdmin manages the fee VALUES.
    // Allowing the owner here too means it can always set fees directly and recover if the admin key is lost.
    modifier onlyFeeAdmin() {
        require(isFeeAdmin[msg.sender] || msg.sender == feeToSetter, 'GunSwapV2: FORBIDDEN');
        _;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    // effective fee for a pair: its override if set, otherwise the default.
    function swapFee(address pair) external view returns (uint) {
        uint fee = swapFeeOverride[pair];
        return fee == 0 ? defaultSwapFee : fee;
    }

    // effective fee + fee vault in a single call. Read by GunSwapV2Pair on every swap.
    function swapFeeInfo(address pair) external view returns (uint fee, address vault) {
        uint f = swapFeeOverride[pair];
        fee = f == 0 ? defaultSwapFee : f;
        vault = feeVault;
    }

    // keccak256 of the exact Pair creation code this factory deploys via CREATE2. Lets the deployer/auditor
    // verify on-chain that GunSwapV2Library.pairFor's hardcoded init code hash matches THIS deployment.
    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(GunSwapV2Pair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'GunSwapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GunSwapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'GunSwapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(GunSwapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IGunSwapV2Pair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        isPair[pair] = true;
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'GunSwapV2: FORBIDDEN');
        emit FeeToChanged(feeTo, _feeTo);
        feeTo = _feeTo;
    }

    // two-step ownership transfer: the current setter nominates a successor, which must then call
    // acceptFeeToSetter. Prevents handing the owner role to a mistyped/uncontrolled address.
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'GunSwapV2: FORBIDDEN');
        pendingFeeToSetter = _feeToSetter;
        emit FeeToSetterTransferStarted(feeToSetter, _feeToSetter);
    }

    function acceptFeeToSetter() external {
        require(msg.sender == pendingFeeToSetter, 'GunSwapV2: FORBIDDEN');
        emit FeeToSetterTransferred(feeToSetter, msg.sender);
        feeToSetter = msg.sender;
        pendingFeeToSetter = address(0);
    }

    // set, change, or remove (pass address(0)) the vault that pairs siphon swap fees to.
    // address(0) switches every pair back to standard V2 behaviour (fee stays in the pool).
    function setFeeVault(address _feeVault) external {
        require(msg.sender == feeToSetter, 'GunSwapV2: FORBIDDEN');
        emit FeeVaultChanged(feeVault, _feeVault);
        feeVault = _feeVault;
    }

    // authorise (allowed=true) or revoke (allowed=false) an operational swap-fee admin. Multiple admins
    // may be active at once; each acts independently and its msg.sender attributes every fee change to it.
    // Owner-only, so any admin key can be revoked here.
    function setFeeAdmin(address _feeAdmin, bool allowed) external {
        require(msg.sender == feeToSetter, 'GunSwapV2: FORBIDDEN');
        require(_feeAdmin != address(0), 'GunSwapV2: ZERO_ADDRESS');
        isFeeAdmin[_feeAdmin] = allowed;
        emit FeeAdminChanged(_feeAdmin, allowed);
    }

    // change the default fee applied to every pair that has no override
    function setDefaultSwapFee(uint _fee) external onlyFeeAdmin {
        require(_fee > 0 && _fee <= MAX_SWAP_FEE, 'GunSwapV2: INVALID_FEE');
        emit DefaultSwapFeeChanged(defaultSwapFee, _fee);
        defaultSwapFee = _fee;
    }

    // set a single pair's fee. Pass 0 to clear the override and let the pair fall back to the default.
    function setSwapFee(address pair, uint _fee) external onlyFeeAdmin {
        require(isPair[pair], 'GunSwapV2: NOT_A_PAIR'); // only pairs created by this factory
        require(_fee <= MAX_SWAP_FEE, 'GunSwapV2: INVALID_FEE');
        emit SwapFeeChanged(pair, swapFeeOverride[pair], _fee);
        swapFeeOverride[pair] = _fee;
    }
}
