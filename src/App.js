import React, { Component } from "react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import { connect } from "react-redux";
import { toast } from "react-toastify";
import Web3 from "web3";
import contract from "@truffle/contract";
import contractMeta from "../build/contracts/VibeStake.json";

// 页面组件
import Artist from "./components/Artist";
import Listener from "./components/Listener";
import Registration from "./Registration";
import Offline from "./components/Offline";
import Loading from "./components/Loading";
import "./App.scss";

export class App extends Component {
  constructor(props) {
    super(props);
    this.web3 = new Web3(Web3.givenProvider || process.env.REACT_APP_GANACHECLI);
    this.contract = contract(contractMeta);
    this.contract.setProvider(this.web3.currentProvider);
    this.state = {
      loading: true,
      username: "",
      account: "",
      type: "", // "0": 未注册, "1": Artist, "2": Listener, "3": Platform
    };
  }

  async componentDidMount() {
    try {
      await this.loadBlockchain();
      toast.success("Blockchain loaded");
      await this.loginUser();
    } catch (error) {
      console.error("Initialization error:", error);
      toast.error("Initialization error: " + error.message);
    }
  }

  async loadBlockchain() {
    const accounts = await this.web3.eth.requestAccounts();
    if (!accounts || accounts.length === 0) {
      throw new Error("No accounts found, please check MetaMask");
    }
    this.setState({ account: accounts[0] });
  }

  // 调用合约中的 getUserType 判断当前账户身份
  loginUser = async () => {
    const contractInstance = await this.contract.deployed();
    const userType = await contractInstance.getUserType(this.state.account, { from: this.state.account });
    console.log("User type:", userType.toString()); // 如果返回 BN 或单个数字

    this.setState({ type: userType.toString(), loading: false });
  };

  // 注销后重置状态，并跳转到注册页面
  logoutUser = () => {
    this.setState({ username: "", type: "0" });
    toast.info("Logged out");
    window.location.href = "/";
  };

  render() {
    if (!navigator.onLine) {
      return <Offline />;
    }
    if (this.state.loading) {
      return <Loading />;
    }
    return (
      <Router>
        <Routes>
          <Route
            path="/"
            element={
              this.state.type === "0" ? (
                <Registration account={this.state.account} onRegistration={this.loginUser} />
              ) : this.state.type === "1" ? (
                <Navigate to="/artist" />
              ) : this.state.type === "2" ? (
                <Navigate to="/listener" />
              ) : (
                <div>
                  <h2>Platform interface not implemented</h2>
                </div>
              )
            }
          />
          <Route
            path="/artist/*"
            element={<Artist contract={this.contract} account={this.state.account} logoutUser={this.logoutUser} />}
          />
          <Route
            path="/listener/*"
            element={<Listener contract={this.contract} account={this.state.account} logoutUser={this.logoutUser} />}
          />
        </Routes>
      </Router>
    );
  }
}

const mapStateToProps = (state) => ({});
const mapDispatchToProps = {};
export default connect(mapStateToProps, mapDispatchToProps)(App);
