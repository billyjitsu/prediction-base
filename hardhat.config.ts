import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config();


const config: HardhatUserConfig = {

solidity: {
  compilers: [
    {
      version: "0.8.19",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
    {
      version: "0.8.9",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    }
  ],
},

networks: {
  
  hardhat: {
    chainId: 1337
  },
  goerlibase: {
    url: `${process.env.BASE_TEST_RPC_URL}`,
    accounts: [`${process.env.PRIVATE_KEY}`],
    // gas: 200000000,
    // gasPrice: 100000000000,
  }

},
etherscan: {
apiKey: process.env.BASE_API_KEY || ""
},

sourcify: {
  enabled: true
}
};

export default config;

