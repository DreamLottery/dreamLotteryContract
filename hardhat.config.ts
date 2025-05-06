import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true, 
        runs: 1000, 
      },
    },
  },
  networks: {
    worldChainMainnet: {
      url: "https://worldchain-mainnet.g.alchemy.com/public", 
      accounts: [process.env.PRIVATE_KEY!],
      gasPrice: "auto", // ⛽ Deja que Hardhat determine el precio del gas adecuado
      chainId: 480,
    },
  },
};

export default config;