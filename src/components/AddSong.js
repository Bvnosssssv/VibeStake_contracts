import React, { Component } from "react";
import { toast } from "react-toastify";
import "./AddSong.scss";

export class AddSong extends Component {
  constructor(props) {
    super(props);
    this.state = {
      songName: "",
      genre: "",
      songFile: null,
      fakeCID: "FAKE_CID_1234567890", // 固定的伪造CID
    };
  }

  handleSongFileChange = (e) => {
    if (e.target.files && e.target.files[0]) {
      this.setState({ songFile: e.target.files[0] });
    }
  };

  handleUpload = async (e) => {
    e.preventDefault();
    const { songName, genre, songFile } = this.state;
    if (!songName || !genre || !songFile) {
      toast.error("Please fill all fields and select a file.");
      return;
    }
    toast.info("Uploading song file (fake)...");
    setTimeout(() => {
      const fakeCID = this.state.fakeCID;
      toast.success("Upload complete, fake CID: " + fakeCID);
      console.log("Fake upload result:", {
        songName,
        genre,
        fakeCID,
      });
      // 重置表单字段
      this.setState({ songName: "", genre: "", songFile: null });
      // 可选：这里可以调用合约接口将歌曲信息存储到区块链
    }, 1500);
  };

  render() {
    return (
      <div className="add-song">
        <h2>Upload Music</h2>
        <form onSubmit={this.handleUpload}>
          <div className="form-group">
            <label>Song Name:</label>
            <input
              type="text"
              className="form-control"
              value={this.state.songName}
              onChange={(e) => this.setState({ songName: e.target.value })}
              required
            />
          </div>
          <div className="form-group">
            <label>Genre:</label>
            <input
              type="text"
              className="form-control"
              value={this.state.genre}
              onChange={(e) => this.setState({ genre: e.target.value })}
              required
            />
          </div>
          <div className="form-group">
            <label>Select Music File:</label>
            <input type="file" className="form-control" onChange={this.handleSongFileChange} required />
          </div>
          <button type="submit" className="btn btn-upload">
            Upload Music (Fake)
          </button>
        </form>
      </div>
    );
  }
}

export default AddSong;
