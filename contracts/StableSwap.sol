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
    uint32 constant A = 85;

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

    modifier hasTokens(address[] memory tokens, uint256[] memory amounts) {
        for (uint8 i = 0; i < tokens.length; i++)
            require(
                ERC20(tokens[i]).balanceOf(msg.sender) >= amounts[i],
                "Insufficient ERC20 balance."
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
            pool.amounts = new uint256[](pool.addresses.length);
            pool.created = true;
            string memory poolName = _tokenSymbols[i][0];
            for (uint8 j = 1; j < _tokenSymbols[i].length; j++)
                poolName = string.concat(poolName, "/", _tokenSymbols[i][j]);

            tokenPools[poolName] = pool;
            contracts.push(poolName);
        }
        priceFeed = PriceFeed(_priceFeed);
    }

    function estimateDeposit(
        string memory _pair,
        uint8 _token,
        uint256 _tokenAmount
    ) external view returns (uint256[] memory) {
        Pool memory pool = tokenPools[_pair];
        uint256[] memory prices = new uint256[](pool.symbols.length);
        if (!poolIsSeeded(_pair)) {
            for (uint8 i = 0; i < pool.symbols.length; i++)
                prices[i] =
                    (priceFeed.getPrice(pool.addresses[i])) *
                    _tokenAmount;

            return prices;
        }

        pool.amounts[_token] += _tokenAmount;
        uint256 sum = getTotalTokensAmount(pool);
        for (uint8 i = 0; i < pool.amounts.length; i++)
            prices[i] = sum / pool.amounts[i];

        return prices;
    }

    function deposit(string memory _pair, uint256[] memory _amounts)
        external
        poolCreated(_pair)
        hasTokens(tokenPools[_pair].addresses, _amounts)
    {
        Pool memory pool = tokenPools[_pair];
        for (uint8 i = 0; i < pool.symbols.length; i++) {
            pool.amounts[i] += _amounts[i];
            ERC20(pool.addresses[i]).transferFrom(
                msg.sender,
                address(this),
                _amounts[i]
            );
        }

        tokenPools[_pair] = pool;
    }

    function swap(
        string memory _pool,
        uint8 fromToken,
        uint8 toToken,
        uint256 amount
    ) external {
        Pool memory pool = tokenPools[_pool];
        console.log(pool.amounts[toToken]);
        ERC20(pool.addresses[fromToken]).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        uint256[] memory initialAmounts = pool.amounts;
        pool.amounts[fromToken] += amount;
        uint256 y = getY(pool, fromToken, toToken, amount);
        console.log(y);
    }

    function getY(
        Pool memory pool,
        uint8 fromTokenIndex,
        uint8 toTokenIndex,
        uint256 tokenInput
    ) public pure returns (uint256) {
        //Pool memory pool = tokenPools[_pair];
        uint256 D = getD(pool);
        uint256 c = D;
        uint256 S = 0;
        for (uint8 i = 0; i < pool.amounts.length; i++) {
            if (i != fromTokenIndex && i == toTokenIndex) continue;
            uint256 x = i == fromTokenIndex ? tokenInput : pool.amounts[i];
            S += x;
            c = (c * D) / (x * pool.amounts.length);
        }
        c = (c * D) / (A * pool.amounts.length**2);
        uint256 b = S + (D / A) * pool.amounts.length;
        uint256 y_prev = 0;
        uint256 y = D;
        for (uint8 _i = 0; _i < 255; _i++) {
            y_prev = y;
            y = (y * y + c) / (2 * y + b - D);
            if (y > y_prev) {
                if (y - y_prev <= 1) break;
            } else {
                if (y_prev - y <= 1) break;
            }
        }

        return y;
    }

    function getD(Pool memory pool) public pure returns (uint256) {
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

    function getContracts() external view returns (string[] memory) {
        return contracts;
    }

    function getPool(string memory _pair) external view returns (Pool memory) {
        return tokenPools[_pair];
    }

    function poolIsSeeded(string memory _pair) internal view returns (bool) {
        return tokenPools[_pair].amounts[0] != 0;
    }

    function poolExists(string memory _pair) external view returns (bool) {
        return tokenPools[_pair].created;
    }

    function getTotalTokensAmount(Pool memory pool)
        internal
        pure
        returns (uint256)
    {
        uint256 sum;
        for (uint8 i = 0; i < pool.amounts.length; i++) sum += pool.amounts[i];

        return sum;
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
}
