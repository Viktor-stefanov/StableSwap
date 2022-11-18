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

async function swap(pool, fromToken, toToken, amount) {
  const ethAmount = ethers.utils.parseEther(amount),
    fromTokenIndex = pool.split("/").indexOf(fromToken),
    toTokenIndex = pool.split("/").indexOf(toToken),
    tokenCon = fromToken === "UCMC" ? ucmc : fromToken === "UTMC" ? utmc : null;

  const user = await tokenCon.signer.getAddress();
  if ((await tokenCon.allowance(ss.address, user)) < ethAmount)
    await tokenCon.approve(ss.address, ethAmount);

  await stableSwap.swap(pool, fromTokenIndex, toTokenIndex, ethAmount);
}

async function getRelativePrice(pool, fromToken, toToken, amount) {
  const fromTokenIndex = pool.split("/").indexOf(fromToken);
  const toTokenIndex = pool.split("/").indexOf(toToken);

  const equivalentAmount = ethers.utils.formatEther(
    await stableSwap.getRelativePrice(
      pool,
      fromTokenIndex,
      toTokenIndex,
      ethers.utils.parseEther(amount)
    )
  );

  return equivalentAmount;
}

async function estimatePoolPrices(pool, token, amount) {
  const tokens = pool.split("/"),
    tokenIndex = tokens.indexOf(token),
    prices = await stableSwap.estimateDeposit(
      pool,
      tokenIndex,
      ethers.utils.parseEther(amount).toString()
    );

  const tokenPrices = {};
  for (let i = 0; i < prices.length; i++)
    tokenPrices[tokens[i]] = ethers.utils.formatEther(prices[i]);

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

  return pools;
}

async function once() {
  let estimates = await stableSwap.estimateDeposit("UTMC/UCMC", 0, ethers.utils.parseEther("1000"));
  console.log(estimates.map((est) => ethers.utils.formatEther(est)));
  const amount = ethers.utils.parseEther("10000");
  await (await utmc.approve(ss.address, amount)).wait();
  await (await ucmc.approve(ss.address, amount)).wait();
  await (await stableSwap.deposit("UTMC/UCMC", [amount, amount])).wait();
  estimates = await stableSwap.estimateDeposit("UTMC/UCMC", 0, ethers.utils.parseEther("1000"));
  console.log(estimates.map((est) => ethers.utils.formatEther(est)));
}

let i = 0;
async function test() {
  if (i === 0) await once();
  i++;
  //await (await utmc.approve(ss.address, ethers.utils.parseEther("1000"))).wait();
  //console.log(
  //  ethers.utils.formatEther(
  //    await stableSwap.getRelativePrice("UTMC/UCMC", 0, 1, ethers.utils.parseEther("1000"))
  //  )
  //);
}

//await test();

export { deposit, getRelativePrice, getAllTokens, swap, estimatePoolPrices, getActivePools };
