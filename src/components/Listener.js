// Listener.js
import React, { Component } from "react";
import { connect } from "react-redux";
import { toast } from "react-toastify";
import Web3 from "web3";
import "./Listener.scss";

export class Listener extends Component {
  constructor(props) {
    super(props);
    this.web3 = new Web3(Web3.givenProvider || process.env.REACT_APP_GANACHECLI);
    this.state = {
      name: "",
      listenerID: "",
      library: [], // 已拥有的歌曲
      store: [],   // 可购买的歌曲
      demos: [],   // 所有 Demo
      query: "",
      currentView: "Library", // "Library"、"Store"、"Demos"
      // 捐赠表单字段（针对 Demo 捐赠）
      donateDemoID: "",
      donateAmount: "",
    };
  }

  async componentDidMount() {
    try {
      await this.loadListenerDetails();
      await this.loadSongDetails();
      await this.loadDemoDetails();
      toast.success(`Welcome ${this.state.name}! 🎧`);
    } catch (error) {
      console.error("Error loading listener data:", error);
      toast.error("Failed to load listener data");
    }
  }

  // 获取 Listener 详情（合约中 getListenerDetails 返回 (name, listenerID, ownedSongIDs)）
  loadListenerDetails = async () => {
    try {
      const contractInstance = await this.props.contract.deployed();
      const listenerDetails = await contractInstance.getListenerDetails({ from: this.props.account });
      this.setState({
        name: listenerDetails[0].toString(),
        listenerID: listenerDetails[1].toString(),
      });
    } catch (error) {
      console.error("loadListenerDetails error:", error);
      throw error;
    }
  };

  // 加载歌曲详情，假设 getNumSongs() 返回总歌曲数，getSongDetails 返回 [songName, artistName, genre, ipfsHash, price, timesPurchased]
  loadSongDetails = async () => {
    try {
      const contractInstance = await this.props.contract.deployed();
      const totalSongs = await contractInstance.getNumSongs({ from: this.props.account });
      let lib = [];
      let store = [];
      // 此处逻辑仅为示例，按实际合约逻辑调整
      for (let i = 1; i <= totalSongs.toNumber(); i++) {
        let songDetails = await contractInstance.getSongDetails(i, { from: this.props.account });
        const songObj = {
          songID: i,
          name: songDetails[0],
          artist: songDetails[1],
          genre: songDetails[2],
          hash: songDetails[3],
          cost: songDetails[4].toString(),
          timesPurchased: songDetails[5].toString(),
        };
        // 这里示例：假设 listenerID 数值越大，拥有的歌曲越多（仅作展示，请根据实际逻辑调整）
        if (parseInt(this.state.listenerID) <= i) {
          lib.push(songObj);
        } else {
          store.push(songObj);
        }
      }
      this.setState({ library: lib, store: store });
    } catch (error) {
      console.error("loadSongDetails error:", error);
      toast.error("Failed to load song details");
    }
  };

  // 加载所有 Demo，假设合约中实现 getDemoCount() 和 getDemoDetails(uint256)
  loadDemoDetails = async () => {
    try {
      const contractInstance = await this.props.contract.deployed();
      const demoCount = await contractInstance.getDemoCount({ from: this.props.account });
      let demoList = [];
      for (let i = 1; i <= demoCount.toNumber(); i++) {
        let demoDetails = await contractInstance.getDemoDetails(i, { from: this.props.account });
        demoList.push({
          demoID: i,
          name: demoDetails[0],
          artist: demoDetails[1],
          genre: demoDetails[2],
          donationDays: demoDetails[3].toString(),
          hash: demoDetails[4],
        });
      }
      this.setState({ demos: demoList });
    } catch (error) {
      console.error("loadDemoDetails error:", error);
      toast.error("Failed to load demo details");
    }
  };

  // 播放歌曲或 Demo 音频
  playAudio = (cid) => {
    const url = `https://${cid}.ipfs.dweb.link`;
    window.open(url, "_blank");
    toast.success("Audio loaded");
  };

  // 购买歌曲
  buySong = async (songID, cost) => {
    try {
      const contractInstance = await this.props.contract.deployed();
      await contractInstance.purchaseSong(songID, 1, cost, 1, { from: this.props.account });
      toast.success("Song purchased!");
      await this.loadSongDetails();
    } catch (error) {
      console.error("buySong error:", error);
      toast.error("Purchase failed");
    }
  };

  // 捐赠 Demo，调用合约 donateDemoListener
  handleDonate = async (e) => {
    e.preventDefault();
    try {
      const contractInstance = await this.props.contract.deployed();
      await contractInstance.donateDemoListener(
        parseInt(this.state.donateDemoID),
        { from: this.props.account, value: this.web3.utils.toWei(this.state.donateAmount, "milliether") }
      );
      toast.success("Donation sent!");
      this.setState({ donateDemoID: "", donateAmount: "" });
    } catch (error) {
      console.error("Donation error:", error);
      toast.error("Donation failed");
    }
  };

  // 切换视图：Library、Store、Demos
  switchView = (view) => {
    this.setState({ currentView: view });
  };

  renderSongs = (songs, type) => {
    return songs
      .filter((song) => song.name.toLowerCase().includes(this.state.query.toLowerCase()))
      .map((song) => (
        <div className="song-card" key={song.hash}>
          <div className="song-card-header">
            <h3>{song.name}</h3>
          </div>
          <div className="song-card-body">
            <p><strong>Genre:</strong> {song.genre}</p>
            <p><strong>Price:</strong> {this.web3.utils.fromWei(song.cost, "milliether")}</p>
            <p><strong>Purchased:</strong> {song.timesPurchased} times</p>
            {type === "store" ? (
              <button className="btn btn-buy" onClick={() => this.buySong(song.songID, song.cost)}>
                Buy 💰
              </button>
            ) : (
              <button className="btn btn-play" onClick={() => this.playAudio(song.hash)}>
                Play 🎶
              </button>
            )}
          </div>
        </div>
      ));
  };

  renderDemos = () => {
    return this.state.demos
      .filter((demo) => demo.name.toLowerCase().includes(this.state.query.toLowerCase()))
      .map((demo) => (
        <div className="demo-card" key={demo.hash}>
          <div className="demo-card-header">
            <h3>{demo.name}</h3>
          </div>
          <div className="demo-card-body">
            <p><strong>Genre:</strong> {demo.genre}</p>
            <p><strong>Donation Days:</strong> {demo.donationDays}</p>
            <button className="btn btn-play" onClick={() => this.playAudio(demo.hash)}>
              Play Demo 🎶
            </button>
          </div>
        </div>
      ));
  };

  render() {
    return (
      <div id="listener" className="app container-fluid">
        <header className="listener-header d-flex justify-content-between align-items-center">
          <div className="header-info">
            <h1>{this.state.name}</h1>
            <p><strong>Listener ID:</strong> {this.state.listenerID}</p>
          </div>
          <div className="header-actions">
            <button className="btn btn-switch" onClick={() => this.switchView("Library")}>
              Library
            </button>
            <button className="btn btn-switch" onClick={() => this.switchView("Store")}>
              Store
            </button>
            <button className="btn btn-switch" onClick={() => this.switchView("Demos")}>
              Demos
            </button>
            <button className="btn btn-logout" onClick={this.props.logoutUser}>
              Logout
            </button>
          </div>
        </header>

        <section className="listener-content row">
          <div className="col-md-12">
            <div className="search-bar my-4 text-center">
              <input
                type="search"
                className="form-control w-50 mx-auto"
                placeholder="Search..."
                onChange={(e) => this.setState({ query: e.target.value })}
              />
            </div>
            {this.state.currentView === "Library" ? (
              <div className="songs-grid d-flex flex-wrap justify-content-center">
                {this.renderSongs(this.state.library, "library")}
              </div>
            ) : this.state.currentView === "Store" ? (
              <div className="songs-grid d-flex flex-wrap justify-content-center">
                {this.renderSongs(this.state.store, "store")}
              </div>
            ) : (
              <div className="demos-grid d-flex flex-wrap justify-content-center">
                {this.renderDemos()}
                <div className="donation-section my-4">
                  <h3>Donate to a Demo</h3>
                  <form onSubmit={this.handleDonate} className="donation-form">
                    <div className="form-group">
                      <label>Demo ID:</label>
                      <input
                        type="number"
                        className="form-control"
                        value={this.state.donateDemoID}
                        onChange={(e) => this.setState({ donateDemoID: e.target.value })}
                        required
                      />
                    </div>
                    <div className="form-group">
                      <label>Amount (mETH):</label>
                      <input
                        type="text"
                        className="form-control"
                        value={this.state.donateAmount}
                        onChange={(e) => this.setState({ donateAmount: e.target.value })}
                        required
                      />
                    </div>
                    <button type="submit" className="btn btn-donate">Donate</button>
                  </form>
                </div>
              </div>
            )}
          </div>
        </section>

        <footer className="listener-footer text-center py-3">
          <p>&copy; {new Date().getFullYear()} Knack. All rights reserved.</p>
        </footer>
      </div>
    );
  }
}

const mapStateToProps = (state) => ({});
const mapDispatchToProps = {};
export default connect(mapStateToProps, mapDispatchToProps)(Listener);
