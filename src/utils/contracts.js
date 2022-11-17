import { ethers } from "ethers";
import usdt from "../../deployments/localhost/UsdtContract.json";
import usdc from "../../deployments/localhost/UsdcContract.json";
import usdv from "../../deployments/localhost/UsdvContract.json";
import pf from "../../deployments/localhost/PriceFeed.json";
import ss from "../../deployments/localhost/StableSwap.json";

const { stableSwap, priceFeed, utmc, ucmc, uvmc } = await instantiateContracts();

async function instantiateContracts() {
  const web3provider = new ethers.providers.Web3Provider(window.ethereum),
    provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545/"),
    web3signer = web3provider.getSigner(),
    signer = provider.getSigner(),
    utmc = new ethers.Contract(usdt.address, usdt.abi, web3signer),
    ucmc = new ethers.Contract(usdc.address, usdc.abi, web3signer),
    uvmc = new ethers.Contract(usdv.address, usdv.abi, web3signer),
    priceFeed = new ethers.Contract(pf.address, pf.abi, signer),
    stableSwap = new ethers.Contract(ss.address, ss.abi, web3signer);

  return {
    stableSwap,
    priceFeed,
    utmc,
    ucmc,
    uvmc,
  };
}

async function deposit(pool, tokenAmounts) {
  const user = await stableSwap.signer.getAddress(),
    tokens = Object.keys(tokenAmounts),
    contracts = tokens.map((token) => (token === "UTMC" ? utmc : token === "UCMC" ? ucmc : uvmc)),
    amounts = Object.values(tokenAmounts).map((amount) =>
      ethers.utils.parseEther(amount.toString())
    );

  for (let i = 0; i < contracts.length; i++) {
    const allowance = await contracts[i].allowance(ss.address, user);
    if (allowance < amounts[i]) await contracts[i].approve(ss.address, amounts[i]);
  }

  await stableSwap.deposit(pool, amounts);
}

async function swap(fromToken, toToken, amount) {
  try {
    let pair = `${fromToken}/${toToken}`,
      t1ToT2 = true,
      tokenCon = fromToken === "UCMC" ? usdcContract : fromToken === "UTMC" ? usdtContract : null;

    if (!(await stableSwap.poolExists(pair))) {
      pair = `${toToken}/${fromToken}`;
      t1ToT2 = false;
      tokenCon = toToken === "UCMC" ? usdcContract : toToken === "UTMC" ? usdtContract : null;
    }

    const user = await tokenCon.signer.getAddress();
    if ((await tokenCon.allowance(stableSwap.address, user)) < amount)
      await tokenCon.approve(stableSwap.address, amount);

    console.log(await stableSwap.poolExists(pair));
    console.log(tokenCon.address);
    await stableSwap.swap(pair, amount, t1ToT2);
  } catch (err) {
    console.log(`Error on swapping ERC20 for ERC20. ${err}`);
  }
}

async function swapTokens(fromToken, fromAmount, toToken) {
  await swap(fromToken, toToken, ethers.utils.parseEther(fromAmount));
}

async function getPrice(fromToken, toToken, amount) {
  let pair = `${fromToken}/${toToken}`,
    t1ToT2 = true;
  if (!(await stableSwap.poolExists(pair))) {
    pair = `${toToken}/${fromToken}`;
    t1ToT2 = false;
  }

  const equivalentAmount = ethers.utils.formatEther(
    await stableSwap.getRelativePrice(pair, ethers.utils.parseEther(amount), t1ToT2)
  );

  return equivalentAmount;
}

async function getRelativePrice(fromToken, toToken, fromAmount) {
  return await getPrice(fromToken, toToken, fromAmount);
}

async function estimatePoolPrices(pool, token, amount) {
  const tokens = pool.split("/"),
    tokenIndex = tokens.indexOf(token),
    prices = await stableSwap.estimateDeposit(pool, tokenIndex, amount);

  const tokenPrices = {};
  for (let i = 0; i < prices.length; i++) tokenPrices[tokens[i]] = prices[i];

  return tokenPrices;
}

async function getAllTokens() {
  let allTokens = new Set();
  const contracts = await stableSwap.getContracts();
  for (let contract of contracts) {
    const tokens = contract.split("/");
    for (let token of tokens) allTokens.add(token);
  }

  return Array.from(allTokens);
}

async function getActivePools() {
  const pools = {},
    poolNames = await stableSwap.getContracts();
  for (let poolName of poolNames) {
    if (await stableSwap.poolExists(poolName)) pools[poolName] = poolName.split("/");
  }
  console.log(pools);

  return pools;
}

async function test() {
  const amount = ethers.utils.parseEther("1000");
  await utmc.approve(ss.address, amount);
  console.log(await stableSwap.swap("UTMC/UCMC/UVMC", 0, 1, amount));
}

await test();

export { deposit, getRelativePrice, getAllTokens, swapTokens, estimatePoolPrices, getActivePools };
