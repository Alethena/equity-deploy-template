// var HDWalletProvider = require("truffle-hdwallet-provider");

module.exports = {
  contracts_directory: './contracts/',
  compilers: {
    solc: {
      version: '0.5.10',
      docker: false,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      },
       evmVersion: 'petersburg',
    }
  },
  networks: {
    development: {
      host: 'localhost',
      port: 9545,
      network_id: '*', // Match any network id
      gas: 0x7a1200
    },
    coverage: {
      host: 'localhost',
      network_id: '*',
      port: 8555, // <-- If you change this, also set the port option in .solcover.js
      gas: 0xfffffffffff, // <-- Use this high gas value
      gasPrice: 0x01 // <-- Use this low gas price
    },
    rinkeby : {
      host: '169.62.164.37',
      port: 8545,
      network_id: 4, // Match any network id
    }, 
    production : {
      host: '169.62.164.45',
      port: 8545,
      network_id: 1, // Match any network id,
      gasPrice: 30 * 10 ** 9
    }
  }
};
