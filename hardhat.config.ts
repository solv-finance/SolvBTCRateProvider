import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "hardhat-deploy";
import "hardhat-tracer";

import { execSync } from "child_process";

import * as dotenv from "dotenv";
dotenv.config();

// Get master password using synchronous method
function getMasterKey() {
  try {
    process.stdout.write("Enter your master password: ");
    // Use spawnSync instead of execSync
    const { spawnSync } = require("child_process");
    const result = spawnSync("bash", ["-c", "read -s line && echo $line"], {
      stdio: ["inherit", "pipe", "inherit"],
      encoding: "utf8",
    });
    const masterKey = result.stdout.trim();
    return masterKey;
  } catch (error) {
    console.error("Error getting master password:", error);
    process.exit(1);
  }
}
const taskName = process.argv[2];

export function getPrivateKey() {
  if (taskName !== "deploy") {
    return process.env.PRIVATE_KEY || undefined;
  }
  if (process.env.PRIVATE_KEY !== undefined) {
    return process.env.PRIVATE_KEY;
  }
  try {
    const masterKey = getMasterKey();
    return execSync(
      `export MASTER_KEY=${masterKey} && /usr/local/bin/solv-key dec`,
      { encoding: "utf8" } // Add encoding option
    )
      .split("=")[0]
      .trim();
  } catch (error) {
    console.error("Error getting private key:", error);
    process.exit(1);
  }
}

const PRIVATE_KEY = getPrivateKey();

const config: HardhatUserConfig = {
  solidity: "0.8.28",

  namedAccounts: {
    deployer: 0,
  },

  networks: {
    sepolia: {
      url: process.env.SEPOLIA_URL || `https://sepolia.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
    mainnet: {
      url: process.env.ETH_URL || `https://mainnet.infura.io/v3/${process.env.INFURA_KEY}`,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    },
  }

};

export default config;
