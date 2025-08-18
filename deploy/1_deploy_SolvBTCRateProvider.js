const transparentUpgrade = require("./utils/transparentUpgrade");

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer } = await getNamedAccounts();

  const contractName = "SolvBTCRateProvider";
  const firstImplName = contractName + "Impl";
  const proxyName = contractName + "Proxy";

  const reserveFeed = "461790bDAF5aeD3df6a88cB97Dec42DD0EFA73c0";
  const updater = "0x4AFA6424e6a0ee021d4676238cdd4feA94799a96";
  const maxDifferencePercent = ethers.utils.parseEther("0.05");

  const versions = {};
  const upgrades = versions[network.name]?.map((v) => {return firstImplName + "_" + v;}) || [];

  const { proxy, newImpl, newImplName } =
    await transparentUpgrade.deployOrUpgrade(
      firstImplName,
      proxyName,
      {
        contract: contractName,
        from: deployer,
        log: true,
      },
      {
        initializer: {
          method: "initialize",
          args: [
            reserveFeed,
            updater,
            maxDifferencePercent,
          ],
        },
        upgrades: upgrades,
      }
    );
};

module.exports.tags = ["SolvBTCRateProvider"];
