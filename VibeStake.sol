// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract VibeStake {

    uint256 artistIDTracker;
    uint256 listenerIDTracker;
    uint256 platformIDTracker;
    uint256 demoIDTracker;
    uint256 songIDTracker;

    constructor() {
        // Initialize the ID trackers
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
        // string hash;
        uint256 demoID;
        uint256 DonationDays;
        string ipfsHash; // IPFS address for storing demo
    }

    struct Song {
        string songName;
        string artistName;
        uint256 artistID;
        string genre;
        // string hash;
        uint256 songID;
        address payable artistAddress;
        uint256 [] platformAuthorized; // platformID // to check the logic
        string ipfsHash; // IPFS address for storing song
        uint256 price; // price for the song / per day, unit is wei(1 ether = 10^18 wei) // to check the logic
        StakeInfo[] stakeInfo; // to check the logic
    }

    struct Donation {
        uint256 DemoID;
        uint256 donationAmount;
        address payable listenerAddress;
    }
    struct StakeInfo{
        uint256 StakeProportion; // 0-100
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

        artistIDTracker++;
        identifyUser[msg.sender] = UserType.ARTIST;
        allArtists[msg.sender] = Artist(_name, artistIDTracker, payable(msg.sender));
    }

    function registerListener(string memory _name) public {
        require(identifyUser[msg.sender] == UserType.UNDEFINED, "User already registered.");
        listenerIDTracker++;
        identifyUser[msg.sender] = UserType.LISTENER;
        allListeners[msg.sender] = Listener(_name, listenerIDTracker);
    }

    function registerPlatform(string memory _name) public {
        require(identifyUser[msg.sender] == UserType.UNDEFINED, "User already registered.");
        platformIDTracker++;
        identifyUser[msg.sender] = UserType.PLATFORM;
        allPlatforms[msg.sender] = Platform(_name, platformIDTracker);
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
        uint256 _donationdays,
        string memory _ipfshash) public {
        require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
        require(!musicHashUsed[_ipfshash], "Duplicate hash has been detected.");
        
        demoIDTracker += 1;
        Demo memory newDemo;
        newDemo.demoName = _demoname;
        newDemo.artistName = allArtists[msg.sender].artistname;
        newDemo.artistID = allArtists[msg.sender].artistID;
        newDemo.genre = _genre;
        newDemo.demoID = demoIDTracker;
        newDemo.artistName = allArtists[msg.sender].artistname;
        newDemo.DonationDays = _donationdays;
        newDemo.ipfsHash = _ipfshash;
        allDemos[demoIDTracker] = newDemo;
        
        musicHashUsed[_ipfshash] = true;
        artistToDemos[allArtists[msg.sender].artistID].push(demoIDTracker);
        emit demoAdded(
            demoIDTracker,
            _demoname,
            allArtists[msg.sender].artistname,
            _donationdays,
            _ipfshash
        );
    }

    // donate the demo and send the donation to the contract temporarily
    // the contract will hold the donation until the song is published
    event demoDonation(
        uint256 demoID,
        uint256 donationAmount,
        address listenerAddress);
    function donateDemoListener(uint256 _demoID) public payable {
        require(identifyUser[msg.sender] == UserType.LISTENER, "Not a listener.");
        require(allDemos[_demoID].demoID != 0, "Demo does not exist.");
        require(msg.value > 0, "Donation amount must be greater than 0.");

        Donation memory newDonation;
        newDonation.DemoID = _demoID;
        newDonation.donationAmount = msg.value;
        newDonation.listenerAddress = payable(msg.sender);
        
        donationListenerRecord[_demoID].push(newDonation);

        emit demoDonation(
            _demoID,
            msg.value,
            msg.sender
        );
    }

    // create song, remove demo and distribute the donation to the artist
    event songAdded(
        uint256 songID,
        string songName,
        string artistName,
        string genre,
        address artistAddress,
        string ipfsHash);

    function addSong(
        string memory _songName,
        string memory _genre,
        uint256 _demoID,
        string memory _ipfshash
        ) public {
        require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
        require(allDemos[_demoID].demoID != 0, "Demo does not exist.");
        require(!musicHashUsed[_ipfshash], "Duplicate hash has been detected.");
        require(allDemos[_demoID].artistID == allArtists[msg.sender].artistID, "Not the owner of the demo.");

        songIDTracker += 1;

        Song memory newSong;
        newSong.songName = _songName;
        newSong.artistName = allArtists[msg.sender].artistname;
        newSong.artistID = allArtists[msg.sender].artistID;
        newSong.genre = _genre;
        newSong.songID = songIDTracker;
        newSong.artistAddress = allArtists[msg.sender].artistAddress;
        newSong.platformAuthorized = new uint256[](0);
        newSong.ipfsHash = _ipfshash;
        newSong.price = 0; // default price is 0, the artist can set the price later

        musicHashUsed[_ipfshash] = true;
        artistToSongs[allArtists[msg.sender].artistID].push(songIDTracker);
        timesSongPublished[songIDTracker] = block.timestamp;


        // Remove the demo
        delete allDemos[_demoID];
        musicHashUsed[allDemos[_demoID].ipfsHash] = false;

        // Get the donation amount
        uint256 totaldonationAmount = 0;
        for (uint256 i = 0; i < donationListenerRecord[_demoID].length; i++) {
            totaldonationAmount += donationListenerRecord[_demoID][i].donationAmount;
        }
        
        // Record the info of the listeners who donated to the song 
        newSong.stakeInfo = new StakeInfo[](donationListenerRecord[_demoID].length);
        for (uint256 i = 0; i < donationListenerRecord[_demoID].length; i++) {
            newSong.stakeInfo[i] = StakeInfo({
                StakeProportion: donationListenerRecord[_demoID][i].donationAmount * 100 / totaldonationAmount,
                listenerAddress: donationListenerRecord[_demoID][i].listenerAddress
            });
        }
        delete donationListenerRecord[_demoID]; // clear the donation record for the demo
        allSongs[songIDTracker] = newSong;

        // Distribute the donation to the artist
        allArtists[msg.sender].artistAddress.transfer(totaldonationAmount);


        emit songAdded(
            songIDTracker,
            _songName,
            allArtists[msg.sender].artistname,
            _genre,
            allArtists[msg.sender].artistAddress,
            _ipfshash
        );
        }
    // set the price for the song
    event songPriceSet(
        uint256 songID,
        uint256 price);
    function setSongPrice(
        uint256 _songID,
        uint256 _price) public {
        require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
        require(allSongs[_songID].songID != 0, "Song does not exist.");
        require(allSongs[_songID].artistAddress == msg.sender, "Not the owner of the song.");
        allSongs[_songID].price = _price;

        emit songPriceSet(
            _songID,
            _price
        );
    }
    

    // platform purchase the right to publish the song for certain days
    event platformPurchase(
        uint256 songID,
        string songName,
        string artistName,
        uint256 platformID,
        string platformName,
        uint256 purchaseAmount,
        uint256 purchaseDays);

    function purchaseSong(
        uint256 _songID,
        uint256 _platformID,
        uint256 _purchaseAmount,
        uint256 _purchaseDays) public {
        require(identifyUser[msg.sender] == UserType.PLATFORM, "Not a platform.");
        require(allSongs[_songID].songID != 0, "Song does not exist.");
        require(allPlatforms[msg.sender].platformID == _platformID, "Not the owner of the platform.");
        require(_purchaseAmount > allSongs[_songID].price * _purchaseDays, "Purchase amount must be greater than the price.");
        require(_purchaseDays > 0, "Purchase days must be greater than 0.");

        // calculate the shares owned by the listener, and the default is 90% to the artist and 10% to the listener
        uint256 artistShare = _purchaseAmount * 90 / 100;
        uint256 listenerShare = _purchaseAmount * 10 / 100;
        // transfer the purchase amount to the artist
        allSongs[_songID].artistAddress.transfer(artistShare);

        // calculate total donation amount from listeners
        uint256 totalDonationAmount = 0;
        for (uint256 i = 0; i < donationListenerRecord[_songID].length; i++) {
            totalDonationAmount += donationListenerRecord[_songID][i].donationAmount;
        }
        // transfer the listener share to the listener according to their donation amount
        for (uint256 i = 0; i < allSongs[_songID].stakeInfo.length; i++) {
            uint256 listenerShareAmount = listenerShare * allSongs[_songID].stakeInfo[i].StakeProportion / 100;
            allSongs[_songID].stakeInfo[i].listenerAddress.transfer(listenerShareAmount);
        }
        
        
        emit platformPurchase(
            _songID,
            allSongs[_songID].songName,
            allSongs[_songID].artistName,
            allPlatforms[msg.sender].platformID,
            allPlatforms[msg.sender].name,
            _purchaseAmount,
            _purchaseDays
        );
        // add the song to the platform
        platformToSongs[_platformID].push(_songID);
        // add the platform to the song
        allSongs[_songID].platformAuthorized.push(_platformID);
        
        
    }

    // // unauthorize the platform to publish the song after expiration
    // event platformUnauthorized(
    //     uint256 songID,
    //     string songName,
    //     string artistName,
    //     uint256 platformID,
    //     string platformName);
    // function unAuthorizePlatform(){}

    
}
