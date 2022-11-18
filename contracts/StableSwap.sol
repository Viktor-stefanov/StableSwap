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
        for (uint128 i = 0; i < tokens.length; i++)
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
            pool.seedAmounts = new uint256[](pool.addresses.length);
            pool.created = true;
            string memory poolName = _tokenSymbols[i][0];
            for (uint128 j = 1; j < _tokenSymbols[i].length; j++)
                poolName = string.concat(poolName, "/", _tokenSymbols[i][j]);

            tokenPools[poolName] = pool;
            contracts.push(poolName);
        }
        priceFeed = PriceFeed(_priceFeed);
    }

    function estimateDeposit(
        string memory _pair,
        uint128 _token,
        uint256 _tokenAmount
    ) external view returns (uint256[] memory) {
        Pool memory pool = tokenPools[_pair];
        uint256[] memory amounts = new uint256[](pool.symbols.length);
        if (!poolIsSeeded(_pair)) {
            for (uint128 i = 0; i < pool.symbols.length; i++)
                amounts[i] =
                    10**18 *
                    (priceFeed.getPrice(pool.addresses[i])) *
                    _tokenAmount;

            return amounts;
        }

        pool.amounts[_token] += _tokenAmount;

        for (uint128 i = 0; i < pool.amounts.length; i++) {
            console.log(pool.amounts[i]);
            console.log(pool.amounts[_token]);
            amounts[i] = pool.amounts[i] > pool.amounts[_token]
                ? 0
                : pool.amounts[_token] - pool.amounts[i];
        }

        return amounts;
    }

    function deposit(string memory _pair, uint256[] memory _amounts)
        external
        poolCreated(_pair)
        hasTokens(tokenPools[_pair].addresses, _amounts)
    {
        Pool memory pool = tokenPools[_pair];
        for (uint128 i = 0; i < pool.symbols.length; i++) {
            pool.amounts[i] += _amounts[i];
            ERC20(pool.addresses[i]).transferFrom(
                msg.sender,
                address(this),
                _amounts[i]
            );
        }

        if (pool.seedAmounts[0] == 0) {
            for (uint128 i = 0; i < pool.symbols.length; i++)
                pool.seedAmounts[i] += _amounts[i];
        }

        tokenPools[_pair] = pool;
    }

    function swap(
        string memory _pool,
        uint128 fromToken,
        uint128 toToken,
        uint256 amount
    ) external {
        Pool memory pool = tokenPools[_pool];
        uint256 y = getY(pool, fromToken, toToken, amount);
        uint256 tokensOut = pool.amounts[toToken] - y;
        pool.amounts[fromToken] += amount;
        pool.amounts[toToken] -= tokensOut;
        tokenPools[_pool] = pool;

        ERC20(pool.addresses[fromToken]).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        ERC20(pool.addresses[toToken]).transfer(msg.sender, tokensOut);
    }

    function getSum(uint256[] memory nums) internal pure returns (uint256) {
        uint256 sum;
        for (uint128 i = 0; i < nums.length; i++) {
            sum += nums[i];
        }

        return sum;
    }

    function getInitialPrices(Pool memory pool)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory initialPrices = new uint256[](pool.seedAmounts.length);
        uint256 seedAmountsSum = getSum(pool.seedAmounts);
        for (uint128 i = 0; i < pool.seedAmounts.length; i++)
            initialPrices[i] = (10**18 * pool.seedAmounts[i]) / seedAmountsSum;

        return initialPrices;
    }

    function getY(
        Pool memory pool,
        uint128 fromTokenIndex,
        uint128 toTokenIndex,
        uint256 tokenInput
    ) internal pure returns (uint256) {
        uint256 nA = pool.amounts.length * 20;
        uint256 D = getD(pool);
        //console.log("D");
        //console.log(D);
        uint256 c = D;
        uint256 S = 0;
        uint256 x;
        for (uint128 i = 0; i < pool.amounts.length; i++) {
            if (i == fromTokenIndex) x = pool.amounts[i] + tokenInput;
            else if (i != toTokenIndex) x = pool.amounts[i];
            else continue;
            S += x;
            c = (c * D) / (x * pool.amounts.length);
        }
        c = (c * D) / (nA * pool.amounts.length);
        //console.log("c:");
        //console.log(c);

        uint256 b = S + D / nA;
        //console.log("b:");
        //console.log(b);
        uint256 y_prev = 0;
        uint256 y = D;
        for (uint128 _i = 0; _i < 255; _i++) {
            y_prev = y;
            y = (y * y + c) / ((y * 2 + b) - D);
            if (y >= y_prev) {
                if (y - y_prev <= 10**18) break;
            } else {
                if (y_prev - y <= 10**18) break;
            }
        }

        return y;
    }

    function getD(Pool memory pool) public pure returns (uint256) {
        uint256 n = pool.symbols.length;
        uint256 S;
        for (uint128 i = 0; i < pool.amounts.length; i++) S += pool.amounts[i];
        uint256 D = S;
        for (uint128 i = 0; i < 255; i++) {
            uint256 DP = D;
            for (uint128 j = 0; j < pool.amounts.length; j++)
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

    function getRelativePrice(
        string memory _pair,
        uint128 _fromTokenIndex,
        uint128 _toTokenIndex,
        uint256 _fromTokenAmount
    ) external view returns (uint256) {
        Pool memory pool = tokenPools[_pair];
        uint256 newToTokenPool = getY(
            pool,
            _fromTokenIndex,
            _toTokenIndex,
            _fromTokenAmount
        );

        return pool.amounts[_toTokenIndex] - newToTokenPool;
    }
}
