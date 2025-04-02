const VibeStake = artifacts.require("VibeStake");

module.exports = function (deployer) {
  deployer.deploy(VibeStake);
};
