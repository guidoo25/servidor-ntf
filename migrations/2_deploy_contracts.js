const SimpleNftLowerGas = artifacts.require("SimpleNftLowerGas");

module.exports = function (deployer) {
  deployer.deploy(SimpleNftLowerGas);
};
