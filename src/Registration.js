import React, { Component } from "react";
import { toast } from "react-toastify";
import Web3 from "web3";
import contract from "@truffle/contract";
import contractMeta from "../build/contracts/VibeStake.json";
import "./Registration.scss";

class Registration extends Component {
  constructor(props) {
    super(props);
    this.web3 = new Web3(Web3.givenProvider || process.env.REACT_APP_GANACHECLI);
    this.contract = contract(contractMeta);
    this.contract.setProvider(this.web3.currentProvider);
    this.state = {
      username: "",
      userType: "1", // "1": Artist, "2": Listener, "3": Platform
      loading: false,
    };
  }

  handleInputChange = (e) => {
    this.setState({ username: e.target.value });
  };

  handleUserTypeChange = (e) => {
    this.setState({ userType: e.target.value });
  };

  handleRegister = async (e) => {
    e.preventDefault();
    this.setState({ loading: true });
    try {
      const contractInstance = await this.contract.deployed();
      const account = this.props.account;
      // 根据选择的身份调用不同的注册函数
      if (this.state.userType === "1") {
        await contractInstance.registerArtist(this.state.username, { from: account });
      } else if (this.state.userType === "2") {
        await contractInstance.registerListener(this.state.username, { from: account });
      } else if (this.state.userType === "3") {
        await contractInstance.registerPlatform(this.state.username, { from: account });
      }
      toast.success("Registration successful");
      // 注册完成后，调用传入的回调刷新用户类型
      this.props.onRegistration();
    } catch (error) {
      console.error("Registration error:", error);
      toast.error("Registration failed: " + error.message);
    } finally {
      this.setState({ loading: false });
    }
  };

  render() {
    return (
      <div className="registration-container">
        <h2>Register Your Account</h2>
        <form onSubmit={this.handleRegister} className="registration-form">
          <div className="form-group">
            <label>Username:</label>
            <input
              type="text"
              value={this.state.username}
              onChange={this.handleInputChange}
              placeholder="Enter your username"
              required
            />
          </div>
          <div className="form-group">
            <label>User Type:</label>
            <select value={this.state.userType} onChange={this.handleUserTypeChange}>
              <option value="1">Artist</option>
              <option value="2">Listener</option>
              <option value="3">Platform</option>
            </select>
          </div>
          <button type="submit" disabled={this.state.loading}>
            {this.state.loading ? "Registering..." : "Register"}
          </button>
        </form>
      </div>
    );
  }
}

export default Registration;
