var Payroll = artifacts.require("./Payroll.sol");
var ERC20Factory = artifacts.require("./tokens/ERC20Factory.sol");
var ERC223Factory = artifacts.require("./tokens/ERC223Factory.sol");
var OracleMockup = artifacts.require("./OracleMockup.sol");
var OracleFailMockup = artifacts.require("./OracleFailMockup.sol");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(Payroll);
  deployer.deploy(ERC20Factory);
  deployer.deploy(ERC223Factory);
  deployer.deploy(OracleMockup);
  deployer.deploy(OracleFailMockup);
};
