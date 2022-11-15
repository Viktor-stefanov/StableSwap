// SPDX-License-Identifier: no-license
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PriceFeed.sol";
import "hardhat/console.sol";

contract StableSwap is ERC20 {
    PriceFeed priceFeed;
    mapping(string => Pool) tokenPools;
    string[] contracts;
    uint256 constant precisionMult = 10**16;
    uint32 constant A = 75;

    struct Pool {
        string[] symbols;
        address[] addresses;
        uint256[] amounts;
        uint256[] seedAmounts;
        bool created;
    }

    modifier poolCreated(string memory _pair) {
        require(
            tokenPools[_pair].created,
            "There is no such token contract YET deployed in our system."
        );
        _;
    }

    modifier hasTokens(address _contract, uint256 _tokenAmount) {
        require(
            ERC20(_contract).balanceOf(msg.sender) >= _tokenAmount,
            "Insufficient ERC20 funds."
        );
        _;
    }

    constructor(
        address[][] memory _tokenAddresses,
        string[][] memory _tokenSymbols,
        address _priceFeed
    ) ERC20("StableSwapCoin", "SSC") {
        for (uint256 i = 0; i < _tokenAddresses.length; i += 2) {
            Pool memory pool;
            pool.symbols = _tokenSymbols[i];
            pool.addresses = _tokenAddresses[i];
            pool.created = true;
            string memory poolName = _tokenSymbols[i][0];
            for (uint8 j = 1; j < _tokenSymbols[i].length; j++)
                poolName = string.concat(poolName, "/", _tokenSymbols[i][j]);
            contracts.push(poolName);
        }
        priceFeed = PriceFeed(_priceFeed);
    }

    function calculateD(string memory _pair) public view returns (uint256) {
        Pool memory pool = tokenPools[_pair];
        uint256 n = pool.symbols.length;
        uint256 S;
        for (uint8 i = 0; i < pool.amounts.length; i++) S += pool.amounts[i];
        uint256 D = S;
        for (uint8 i = 0; i < 255; i++) {
            uint256 DP = D;
            for (uint8 j = 0; j < pool.amounts.length; j++)
                DP = (DP * D) / (pool.amounts[j] * n);
            uint256 Dprev = D;
            D =
                ((A * n**n * S + DP * n) * D) /
                ((A * n**n - 1) * D + (n + 1) * DP);

            if (D > Dprev && D - Dprev <= 1) break;
            if (Dprev >= D && Dprev - D <= 1) break;
        }

        return D;
    }

    //function getY(
    //    string memory _pair,
    //    uint8 fromTokenIndex,
    //    uint8 toTokenIndex,
    //    uint256 tokenInput
    //) public view {
    //    Pool memory pool = tokenPools[_pair];
    //    uint256 D = calculateD(_pair);
    //}

    function getContracts() external view returns (string[] memory) {
        return contracts;
    }

    function getPool(string memory _pair) external view returns (Pool memory) {
        return tokenPools[_pair];
    }

    function poolIsSeeded(string memory _pair) internal view returns (bool) {
        return tokenPools[_pair].seedAmounts[0] != 0;
    }

    function poolExists(string memory _pair) external view returns (bool) {
        return tokenPools[_pair].created;
    }

    function estimateDeposit(
        string memory _pair,
        uint8 _token,
        uint256 _tokenAmount
    ) external view returns (uint256[] memory) {
        Pool memory pool = tokenPools[_pair];
        uint256[] memory prices;
        if (!poolIsSeeded(_pair)) {
            for (uint8 i = 0; i < pool.symbols.length; i++)
                prices[i] = (priceFeed.getPrice(pool.addresses[i]));
        }

        return prices;
    }

    //function getRelativePrice(
    //    string memory _pair,
    //    uint256 _tokenAmount,
    //    bool _t1ToT2
    //) external view returns (uint256) {
    //    Pool memory pool = tokenPools[_pair];
    //    if (!poolIsSeeded(_pair))
    //        return
    //            _t1ToT2
    //                ? 10**22 * priceFeed.getPrice(pool.token1Con)
    //                : 10**22 * priceFeed.getPrice(pool.token2Con);

    //    uint256 fee = _tokenAmount / 500;
    //    uint256 invariant = A *
    //        n**n *
    //        (pool.token1Amount + pool.token2Amount) +
    //        pool.D;
    //    uint256 newToken1Pool = _t1ToT2
    //        ? pool.token1Amount + _tokenAmount
    //        : ((invariant - pool.D) / (A * n**n)) -
    //            (pool.token2Amount + _tokenAmount);
    //    uint256 newToken2Pool = _t1ToT2
    //        ? ((invariant - pool.D) / (A * n**n)) -
    //            (pool.token1Amount + _tokenAmount)
    //        : pool.token2Amount + _tokenAmount;

    //    console.log(pool.token1Amount);
    //    console.log(newToken1Pool);
    //    console.log(pool.token2Amount);
    //    console.log(newToken2Pool);

    //    return
    //        _t1ToT2
    //            ? pool.token2Amount - newToken2Pool
    //            : pool.token1Amount - newToken1Pool;
    //}

    //function deposit(
    //    string memory _pair,
    //    uint256 _token1Amount,
    //    uint256 _token2Amount
    //)
    //    external
    //    poolCreated(_pair)
    //    hasTokens(tokenPools[_pair].token1Con, _token1Amount)
    //    hasTokens(tokenPools[_pair].token2Con, _token2Amount)
    //{
    //    tokenPools[_pair].token1Amount += _token1Amount;
    //    tokenPools[_pair].token2Amount += _token2Amount;
    //    if (tokenPools[_pair].token1Seed == 0) {
    //        tokenPools[_pair].token1Seed = _token1Amount;
    //        tokenPools[_pair].token2Seed = _token2Amount;
    //        tokenPools[_pair].D = _token1Amount + _token2Amount;
    //    }

    //    ERC20(tokenPools[_pair].token1Con).transferFrom(
    //        msg.sender,
    //        address(this),
    //        _token1Amount
    //    );
    //    ERC20(tokenPools[_pair].token2Con).transferFrom(
    //        msg.sender,
    //        address(this),
    //        _token2Amount
    //    );
    //}

    //function swap(
    //    string memory _pair,
    //    uint256 _tokenAmount,
    //    bool _t1ToT2
    //) external {
    //    require(
    //        _t1ToT2
    //            ? ERC20(tokenPools[_pair].token1Con).balanceOf(msg.sender) >=
    //                _tokenAmount
    //            : ERC20(tokenPools[_pair].token2Con).balanceOf(msg.sender) >=
    //                _tokenAmount,
    //        "Insufficient ERC20 balance."
    //    );

    //    pairPool memory pool = tokenPools[_pair];
    //    uint256 fee = _tokenAmount / 500;
    //    uint256 invariant = pool.token1Amount * pool.token2Amount;
    //    uint256 newToken1Pool;
    //    uint256 newToken2Pool;
    //    uint256 tokensOut;
    //    if (_t1ToT2) {
    //        newToken1Pool = pool.token1Amount + _tokenAmount;
    //        newToken2Pool = invariant / (newToken1Pool - fee);
    //        tokensOut = pool.token2Amount - newToken2Pool;
    //    } else {
    //        newToken2Pool = pool.token2Amount + _tokenAmount;
    //        newToken1Pool = invariant / (newToken2Pool - fee);
    //        tokensOut = pool.token1Amount - newToken1Pool;
    //    }
    //    pool.token1Amount = newToken1Pool;
    //    pool.token2Amount = newToken2Pool;
    //    tokenPools[_pair] = pool;

    //    ERC20 fromContract = _t1ToT2
    //        ? ERC20(pool.token1Con)
    //        : ERC20(pool.token2Con);
    //    ERC20 toContract = _t1ToT2
    //        ? ERC20(pool.token2Con)
    //        : ERC20(pool.token1Con);

    //    fromContract.transferFrom(msg.sender, address(this), _tokenAmount);
    //    toContract.transfer(msg.sender, tokensOut);
    //}
}
