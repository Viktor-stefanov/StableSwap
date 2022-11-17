module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const usdc = await deploy("UsdcContract", {
      from: deployer,
      log: true,
      args: ["0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"],
    }),
    usdt = await deploy("UsdtContract", {
      from: deployer,
      log: true,
      args: ["0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"],
    }),
    usdv = await deploy("UsdvContract", {
      from: deployer,
      log: true,
      args: ["0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"],
    }),
    usdcAggregator = await deploy("UsdcAggregator", {
      from: deployer,
      log: true,
      args: [1, 1],
    }),
    usdtAggregator = await deploy("UsdtAggregator", {
      from: deployer,
      log: true,
      args: [1, 1],
    }),
    usdvAggregator = await deploy("UsdvAggregator", {
      from: deployer,
      log: true,
      args: [1, 1],
    }),
    pf = await deploy("PriceFeed", {
      from: deployer,
      log: true,
      args: [
        [usdc.address, usdt.address, usdv.address],
        [usdcAggregator.address, usdtAggregator.address, usdvAggregator.address],
      ],
    });

  await deploy("StableSwap", {
    from: deployer,
    log: true,
    args: [[[usdt.address, usdc.address, usdv.address]], [["UTMC", "UCMC", "UVMC"]], pf.address],
  });
};
