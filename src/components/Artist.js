import React, { Component } from "react";
import { connect } from "react-redux";
import { toast } from "react-toastify";
import Web3 from "web3";
import AddSong from "./AddSong"; // 上传音乐组件（伪造接口）
import "./Artist.scss";

export class Artist extends Component {
  constructor(props) {
    super(props);
    this.web3 = new Web3(Web3.givenProvider || process.env.REACT_APP_GANACHECLI);
    this.state = {
      name: "",
      artistID: "",
      popularity: 0,
      songIDs: [],
      songs: [],
      demos: [], // 当前艺术家上传的 demo 列表
      query: "",
      currentTab: "music", // "music" 或 "demo"
      // Demo 上传表单字段
      demoname: "",
      demoGenre: "",
      donationDays: "",
      demoIPFS: "",
    };
  }

  async componentDidMount() {
    try {
      await this.loadArtistDetails();
      await this.loadSongDetails();
      if (this.state.currentTab === "demo") {
        await this.loadArtistDemos();
      }
      toast.success(`Welcome ${this.state.name}! 🎤`);
    } catch (error) {
      console.error("Error loading artist data:", error);
      toast.error("Failed to load artist data");
    }
  }

  // 获取艺术家详情，要求合约实现 getArtistDetails() 返回 (artistName, artistID, songIDs)
  loadArtistDetails = async () => {
    try {
      const contractInstance = await this.props.contract.deployed();
      const artistDetails = await contractInstance.getArtistDetails({ from: this.props.account });
      this.setState({
        name: artistDetails[0].toString(),
        artistID: artistDetails[1].toString(),
        songIDs: artistDetails[2].map((id) => id.toString()),
      });
    } catch (error) {
      console.error("loadArtistDetails error:", error);
      throw error;
    }
  };

  // 获取歌曲详情（getSongDetails 返回 [songName, artistName, genre, ipfsHash, price, timesPurchased]）
  loadSongDetails = async () => {
    try {
      const contractInstance = await this.props.contract.deployed();
      let songInfoList = [];
      let totalPopularity = 0;
      for (let i = 0; i < this.state.songIDs.length; i++) {
        let songDetails = await contractInstance.getSongDetails(this.state.songIDs[i], { from: this.props.account });
        songInfoList.push({
          name: songDetails[0],
          genre: songDetails[2],
          hash: songDetails[3],
          cost: songDetails[4].toString(),
          timesPurchased: songDetails[5].toString(),
        });
        totalPopularity += parseInt(songDetails[5].toString());
      }
      this.setState({ songs: songInfoList, popularity: totalPopularity });
    } catch (error) {
      console.error("loadSongDetails error:", error);
      toast.error("Failed to load song details");
    }
  };

  // 获取当前艺术家上传的 Demo 列表，要求合约实现 getDemosByArtist(uint256 _artistID) 返回 demoID 数组，
  // 然后通过 getDemoDetails(uint256 demoID) 返回 [demoName, artistName, genre, donationDays, ipfsHash]
  loadArtistDemos = async () => {
    try {
      const contractInstance = await this.props.contract.deployed();
      const demoIDs = await contractInstance.getDemosByArtist(this.state.artistID, { from: this.props.account });
      let demoList = [];
      for (let i = 0; i < demoIDs.length; i++) {
        let demoDetails = await contractInstance.getDemoDetails(demoIDs[i], { from: this.props.account });
        demoList.push({
          demoID: demoIDs[i].toString(),
          name: demoDetails[0],
          genre: demoDetails[2],
          donationDays: demoDetails[3].toString(),
          hash: demoDetails[4],
        });
      }
      this.setState({ demos: demoList });
    } catch (error) {
      console.error("loadArtistDemos error:", error);
      toast.error("Failed to load demo details");
    }
  };

  // 切换 Tab 时，如果切换到 demo，则加载 Demo 列表
  switchTab = async (tab) => {
    this.setState({ currentTab: tab });
    if (tab === "demo") {
      await this.loadArtistDemos();
    }
  };

  // 播放歌曲
  playAudio = (cid) => {
    const url = `https://${cid}.ipfs.dweb.link`;
    window.open(url, "_blank");
    toast.success("Audio loaded");
  };

  // Demo 上传，调用合约 addDemo
  handleUploadDemo = async (e) => {
    e.preventDefault();
    try {
      if (!this.state.demoname || !this.state.demoGenre || !this.state.donationDays || !this.state.demoIPFS) {
        toast.error("Please fill all fields for demo upload!");
        return;
      }
      const contractInstance = await this.props.contract.deployed();
      await contractInstance.addDemo(
        this.state.demoname,
        this.state.demoGenre,
        this.state.donationDays,
        this.state.demoIPFS,
        { from: this.props.account }
      );
      toast.success("Demo uploaded successfully!");
      // 重置 Demo 表单
      this.setState({ demoname: "", demoGenre: "", donationDays: "", demoIPFS: "" });
      // 刷新 Demo 列表
      await this.loadArtistDemos();
    } catch (error) {
      console.error("handleUploadDemo error:", error);
      toast.error("Failed to upload demo");
    }
  };

  // 渲染音乐列表
  renderSongs = () => {
    return this.state.songs
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
            <button className="btn btn-play" onClick={() => this.playAudio(song.hash)}>
              Play 🎶
            </button>
          </div>
        </div>
      ));
  };

  // 渲染 Demo 列表
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
      <div id="artist" className="app container-fluid">
        <header className="artist-header d-flex justify-content-between align-items-center">
          <div className="header-info">
            <h1>{this.state.name}</h1>
            <p><strong>Artist ID:</strong> {this.state.artistID}</p>
          </div>
          <div className="header-actions">
            <button className={`tab-btn ${this.state.currentTab === "music" ? "active" : ""}`} onClick={() => this.switchTab("music")}>
              Music
            </button>
            <button className={`tab-btn ${this.state.currentTab === "demo" ? "active" : ""}`} onClick={() => this.switchTab("demo")}>
              Demos
            </button>
            <p>Popularity 💟: <span>{this.state.popularity}</span></p>
            <button className="btn btn-logout" onClick={this.props.logoutUser}>Logout</button>
          </div>
        </header>

        <section className="artist-content row">
          <div className="col-md-12">
            <div className="search-bar my-4 text-center">
              <input
                type="search"
                className="form-control w-50 mx-auto"
                placeholder="Search by name..."
                onChange={(e) => this.setState({ query: e.target.value })}
              />
            </div>
            {this.state.currentTab === "music" ? (
              <div>
                <div className="songs-grid d-flex flex-wrap justify-content-center">
                  {this.renderSongs()}
                </div>
                <div className="upload-music-section">
                  <AddSong contract={this.props.contract} account={this.props.account} />
                </div>
              </div>
            ) : (
              <div>
                <div className="demo-upload-section">
                  <h2>Upload a Demo</h2>
                  <form onSubmit={this.handleUploadDemo} className="demo-form">
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
                        value={this.state.demoGenre}
                        onChange={(e) => this.setState({ demoGenre: e.target.value })}
                        required
                      />
                    </div>
                    <div className="form-group">
                      <label>Donation Days</label>
                      <input
                        type="number"
                        className="form-control"
                        value={this.state.donationDays}
                        onChange={(e) => this.setState({ donationDays: e.target.value })}
                        required
                      />
                    </div>
                    <div className="form-group">
                      <label>IPFS Hash (Fake)</label>
                      <input
                        type="text"
                        className="form-control"
                        placeholder="Enter fake CID"
                        value={this.state.demoIPFS}
                        onChange={(e) => this.setState({ demoIPFS: e.target.value })}
                        required
                      />
                    </div>
                    <button type="submit" className="btn btn-publish">Publish Demo</button>
                  </form>
                </div>
                <div className="demos-grid d-flex flex-wrap justify-content-center mt-4">
                  {this.renderDemos()}
                </div>
              </div>
            )}
          </div>
        </section>

        <footer className="artist-footer text-center py-3">
          <p>&copy; {new Date().getFullYear()} Knack. All rights reserved.</p>
        </footer>
      </div>
    );
  }
}

const mapStateToProps = (state) => ({});
const mapDispatchToProps = {};
export default connect(mapStateToProps, mapDispatchToProps)(Artist);
