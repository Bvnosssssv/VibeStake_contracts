// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract VibeStake {

    uint256 artistIDTracker;
    uint256 listenerIDTracker;
    uint256 platformIDTracker;
    uint256 demoIDTracker;
    uint256 songIDTracker;

    constructor(address _userManager) {
        artistIDTracker = 0;
        listenerIDTracker = 0;
        platformIDTracker = 0;
        demoIDTracker = 0;
        songIDTracker = 0;
    }

    enum UserType {
        UNDEFINED,
        ARTIST, 
        LISTENER, // listener can also be a staker of the demo/music
        PLATFORM
    }
    
    struct Artist {
        string artistname;
        uint256 artistID;
        address payable artistAddress;
    }

    struct Listener {
        string name;
        uint256 listenerID;
    }

    struct Platform {
        string name;
        uint256 platformID;
    }

    struct Demo {
        string demoName;
        string artistName;
        uint256 artistID;
        string genre;
        string hash;
        uint256 demoID;
        uint256 DonationDays;
        string ipfsHash; // IPFS address for storing demo
    }

    struct Song {
        string songName;
        string artistName;
        uint256 artistID;
        string genre;
        string hash;
        uint256 songID;
        address payable artistAddress;
        uint256 [] platformAuthorized; // platformID // to check the logic
        string ipfsHash; // IPFS address for storing song
    }

    struct Donation {
        uint256 DemoID;
        uint256 donationAmount;
        address payable listenerAddress;
    }

    mapping(address => UserType) public identifyUser;

    mapping(address => Artist) allArtists;
    mapping(address => Listener) allListeners;
    mapping(address => Platform) allPlatforms;
    mapping(uint256 => Song) allSongs;
    mapping(uint256 => Demo) allDemos;

    mapping(string => bool) musicHashUsed; // including song hash and demo hash
    
    mapping(uint256 => uint256[]) public artistToDemos; // artistID -> demoIDs
    mapping(uint256 => uint256[]) public artistToSongs; // artistID -> songIDs
    mapping(uint256 => Donation[]) donationListenerRecord; // demoId => list of donations
    mapping(uint256 => uint256[]) public platformToSongs; // platformID -> songIDs

    // extra mappings for intellectual property protection
    mapping(uint256 => uint256) timesSongPublished;
    
    function getUserType(address _user) public view returns (UserType) {
        return identifyUser[_user];
    }

    function registerArtist(string memory _name) public {
        require(identifyUser[msg.sender] == UserType.UNDEFINED, "User already registered.");
        identifyUser[msg.sender] = UserType.ARTIST;
        allArtists[msg.sender] = Artist(_name, artistIDTracker, payable(msg.sender));
        artistIDTracker++;
    }

    function registerListener(string memory _name) public {
        require(identifyUser[msg.sender] == UserType.UNDEFINED, "User already registered.");
        identifyUser[msg.sender] = UserType.LISTENER;
        allListeners[msg.sender] = Listener(_name, listenerIDTracker);
        listenerIDTracker++;
    }

    function registerPlatform(string memory _name) public {
        require(identifyUser[msg.sender] == UserType.UNDEFINED, "User already registered.");
        identifyUser[msg.sender] = UserType.PLATFORM;
        allPlatforms[msg.sender] = Platform(_name, platformIDTracker);
        platformIDTracker++;
    }

    // create demo
    event demoAdded(
        uint256 demoID,
        string demoName,
        string artistName,
        uint256 donationDays,
        string ipfsHash);

    function addDemo(
        string memory _demoname,
        string memory _genre,
        string memory _hash,
        uint256 _donationdays,
        string memory _ipfshash) public {
        require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
        require(!musicHashUsed[_hash], "Duplicate hash has been detected.");
        demoIDTracker += 1;
        
        Demo memory newDemo;
        newDemo.demoName = _demoname;
        newDemo.artistName = allArtists[msg.sender].artistname;
        newDemo.artistID = allArtists[msg.sender].artistID;
        newDemo.genre = _genre;
        newDemo.hash = _hash;
        newDemo.demoID = demoIDTracker;
        newDemo.artistName = allArtists[msg.sender].artistname;
        newDemo.DonationDays = _donationdays;
        newDemo.ipfsHash = _ipfshash;
        allDemos[demoIDTracker] = newDemo;
        
        musicHashUsed[_hash] = true;
        artistToDemos[allArtists[msg.sender].artistID].push(demoIDTracker);
        emit demoAdded(
            demoIDTracker,
            _demoname,
            allArtists[msg.sender].artistname,
            _donationdays,
            _ipfshash
        );
        demoIDTracker++;
    }

    // create song and remove demo
    event songAdded(
        uint256 songID,
        string songName,
        string artistName,
        string genre,
        string hash,
        address artistAddress,
        string ipfsHash);

    function addSong(
        string memory _songName,
        string memory _genre,
        string memory _hash,
        uint256 _demoID,
        string memory _ipfshash
        ) public {
        require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
        require(allDemos[_demoID].demoID != 0, "Demo does not exist.");
        require(!musicHashUsed[_hash], "Duplicate hash has been detected.");
        require(allDemos[_demoID].artistID == allArtists[msg.sender].artistID, "Not the owner of the demo.");

        Song memory newSong;
        newSong.songName = _songName;
        newSong.artistName = allArtists[msg.sender].artistname;
        newSong.artistID = allArtists[msg.sender].artistID;
        newSong.genre = _genre;
        newSong.hash = _hash;
        newSong.songID = songIDTracker;
        newSong.artistAddress = allArtists[msg.sender].artistAddress;
        newSong.platformAuthorized = new uint256[](0);
        newSong.ipfsHash = _ipfshash;
        allSongs[songIDTracker] = newSong;

        musicHashUsed[_hash] = true;
        artistToSongs[allArtists[msg.sender].artistID].push(songIDTracker);

        songIDTracker += 1;

        // Remove the demo
        delete allDemos[_demoID];
        musicHashUsed[allDemos[_demoID].hash] = false;

        emit songAdded(
            songIDTracker,
            _songName,
            allArtists[msg.sender].artistname,
            _genre,
            _hash,
            allArtists[msg.sender].artistAddress,
            _ipfshash
        );
        }
    

    // donate the demo
    event demoDonated(
        uint256 demoID,
        uint256 donationAmount,
        address listenerAddress);
    function donateDemo(uint256 _demoID) public payable {}

    // distribute the return from songs to the listeners
    event ReturnsDistributed(
        uint256 songID,
        uint256 donationAmount,
        address listenerAddress);
    function distributeReturns(uint256 _songID) public payable {}
    

    // authorize platform
    event platformAuthorized(
        uint256 songID,
        string songName,
        string artistName,
        uint256 platformID,
        string platformName);

    function authorizePlatform() {}
}
