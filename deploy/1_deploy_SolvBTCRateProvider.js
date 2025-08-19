const transparentUpgrade = require("./utils/transparentUpgrade");

module.exports = async ({ getNamedAccounts, deployments, network }) => {
  const { deployer } = await getNamedAccounts();

  const contractName = "SolvBTCRateProvider";
  const firstImplName = contractName + "Impl";
  const proxyName = contractName + "Proxy";

  const reserveFeed = "0xda9258AFc797Cd64d1b6FC651051224cdAB1B25E";
  const updater = "0x4AFA6424e6a0ee021d4676238cdd4feA94799a96";
  const maxDifferencePercent = ethers.utils.parseEther("0.05");

  const versions = {
    sepolia: ["v1.1"],
    mainnet: ["v1.1"],
  };
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
  
  const SolvBTCRateProviderFactory = await ethers.getContractFactory("SolvBTCRateProvider", deployer);
  const solvBTCRateProvider = SolvBTCRateProviderFactory.attach(proxy.address);

  const currentReserveFeed = await solvBTCRateProvider.getReserveFeed();
  if (currentReserveFeed !== reserveFeed) {
    const setReserveFeedTx = await solvBTCRateProvider.setReserveFeed(reserveFeed);
    console.log("setReserveFeedTx", setReserveFeedTx);
    await setReserveFeedTx.wait();
  }

};

module.exports.tags = ["SolvBTCRateProvider"];
