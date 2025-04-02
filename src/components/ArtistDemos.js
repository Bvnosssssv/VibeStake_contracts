// ArtistDemos.js
import React, { Component } from "react";
import { Link } from "react-router-dom";
import Web3 from "web3";
import { toast } from "react-toastify";
import "./ArtistDemos.scss";

export default class ArtistDemos extends Component {
  constructor(props) {
    super(props);
    this.web3 = new Web3(Web3.givenProvider || process.env.REACT_APP_GANACHECLI);
    this.state = {
      demoname: "",
      genre: "",
      donationdays: "",
      ipfshash: "",
      demos: [],
    };
  }

  componentDidMount() {
    // 可选：加载已有的 Demo 列表
    // this.loadArtistDemos();
  }

  // 调用合约的 addDemo 函数
  handleUploadDemo = async (e) => {
    e.preventDefault();
    try {
      if (!this.state.demoname || !this.state.genre || !this.state.donationdays || !this.state.ipfshash) {
        toast.error("Please fill all fields!");
        return;
      }
      const contractInstance = await this.props.contract.deployed();
      await contractInstance.addDemo(
        this.state.demoname,
        this.state.genre,
        this.state.donationdays,
        this.state.ipfshash,
        { from: this.props.account }
      );
      toast.success("Demo uploaded!");
      // 可选：清空表单
      this.setState({ demoname: "", genre: "", donationdays: "", ipfshash: "" });
      // 可选：刷新 demo 列表
      // this.loadArtistDemos();
    } catch (error) {
      console.error("handleUploadDemo error:", error);
      toast.error("Failed to upload demo");
    }
  };

  // 可选：加载 Demo 列表
  // 需要在合约中实现类似 getDemosByArtist(artistID) 的函数
  // async loadArtistDemos() {
  //   try {
  //     const contractInstance = await this.props.contract.deployed();
  //     const demos = await contractInstance.getDemosByArtist(...);
  //     // demos 可能是 [demoID1, demoID2, ...]
  //     // 然后再逐个获取 Demo 详情
  //     this.setState({ demos: ... });
  //   } catch (err) {
  //     console.error("loadArtistDemos error:", err);
  //   }
  // }

  render() {
    return (
      <div id="artist-demos" className="container-fluid">
        <header className="d-flex justify-content-between align-items-center">
          <h1>Manage Demos</h1>
          <Link to="/artist" className="btn btn-return">
            Back to Artist Page
          </Link>
        </header>

        <main className="d-flex flex-column align-items-center">
          <form className="demo-form" onSubmit={this.handleUploadDemo}>
            <h3>Publish a Demo</h3>
            <div className="form-group">
              <label>Demo Name</label>
              <input
                type="text"
                className="form-control"
                value={this.state.demoname}
                onChange={(e) => this.setState({ demoname: e.target.value })}
                required
              />
            </div>
            <div className="form-group">
              <label>Genre</label>
              <input
                type="text"
                className="form-control"
                value={this.state.genre}
                onChange={(e) => this.setState({ genre: e.target.value })}
                required
              />
            </div>
            <div className="form-group">
              <label>Donation Days</label>
              <input
                type="number"
                className="form-control"
                value={this.state.donationdays}
                onChange={(e) => this.setState({ donationdays: e.target.value })}
                required
              />
            </div>
            <div className="form-group">
              <label>IPFS Hash</label>
              <input
                type="text"
                className="form-control"
                placeholder="Qm..."
                value={this.state.ipfshash}
                onChange={(e) => this.setState({ ipfshash: e.target.value })}
                required
              />
            </div>
            <button type="submit" className="btn btn-publish">
              Upload
            </button>
          </form>

          {/* 可选：在这里展示已发布 Demo 列表 */}
          {/* <div className="demo-list">
            {this.state.demos.map((demo) => (
              <DemoCard key={demo.demoID} demo={demo} />
            ))}
          </div> */}
        </main>

        <footer className="text-center py-3">
          <p>&copy; {new Date().getFullYear()} Knack. All rights reserved.</p>
        </footer>
      </div>
    );
  }
}
