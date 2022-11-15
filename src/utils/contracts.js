import { ethers } from "ethers";
import pf from "../../deployments/localhost/PriceFeed.json";
import ss from "../../deployments/localhost/StableSwap.json";

const { stableSwap, priceFeed } = await instantiateContracts();

async function instantiateContracts() {
  const web3provider = new ethers.providers.Web3Provider(window.ethereum),
    provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545/"),
    web3signer = web3provider.getSigner(),
    signer = provider.getSigner(),
    priceFeed = new ethers.Contract(pf.address, pf.abi, signer),
    stableSwap = new ethers.Contract(ss.address, ss.abi, web3signer);

  return {
    stableSwap,
    priceFeed,
  };
}

async function deposit(fromToken, toToken, fromAmount, toAmount) {
  try {
    const pair = `${fromToken}/${toToken}`,
      user = await stableSwap.signer.getAddress(),
      tok1Contract =
        fromToken === "UCMC" ? usdcContract : fromToken === "UTMC" ? usdtContract : null,
      tok2Contract = toToken === "UCMC" ? usdcContract : toToken === "UTMC" ? usdtContract : null;

    if ((await tok1Contract.allowance(user, stableSwap.address)) < fromAmount)
      await tok1Contract.approve(stableSwap.address, fromAmount);

    if ((await tok2Contract.allowance(user, stableSwap.address)) < toAmount)
      await tok2Contract.approve(stableSwap.address, toAmount);

    await stableSwap.deposit(pair, fromAmount, toAmount);
  } catch (err) {
    console.log(`Error on depositing ERC20/ERC20 pair. ${err}`);
  }
}

async function provideLiquidity(fromToken, fromAmount, toToken, toAmount) {
  await deposit(
    fromToken,
    toToken,
    ethers.utils.parseEther(fromAmount),
    ethers.utils.parseEther(toAmount)
  );
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

async function estimateBalancedDeposit(fromToken, toToken, fromAmount) {
  let pair = `${fromToken}/${toToken}`;
  if (!(await stableSwap.poolExists(pair))) pair = `${toToken}/${fromToken}`;

  return ethers.utils.formatEther(
    (await stableSwap.estimateDeposit(pair, ethers.utils.parseEther(amount), t1ToT2))
      .div(10 ** 8)
      .div(10 ** 8)
  );
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
    pools[poolName] = [poolName.split("/")];
  }

  console.log(pools);
  return pools;
}

//async function test() {
//  console.log(ethers.utils.formatEther(await stableSwap.calculateD("UTMC/UCMC")));
//}

//await test();

export {
  provideLiquidity,
  getRelativePrice,
  getAllTokens,
  swapTokens,
  estimateBalancedDeposit,
  getActivePools,
};
