// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract VibeStake {

    uint256 artistIDTracker;
    uint256 listenerIDTracker;
    uint256 platformIDTracker;
    uint256 demoIDTracker;
    uint256 songIDTracker;
    uint256 semiSongIDTracker; // for the song before voting

    constructor() {
        // Initialize the ID trackers
        artistIDTracker = 0;
        listenerIDTracker = 0;
        platformIDTracker = 0;
        demoIDTracker = 0;
        songIDTracker = 0;
        semiSongIDTracker = 0;
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
        uint256 demoID;
        uint256 DonationDays; // promise final song will be published within this time
        string ipfsHash; // IPFS address for storing demo
        bool finalSongPublished; // whether the song is published or not
    }

    struct Song {
        string songName;
        string artistName;
        uint256 artistID;
        string genre;
        uint256 songID;
        address payable artistAddress;
        uint256 [] platformAuthorized; // platformID 
        string ipfsHash; // IPFS address for storing song
        uint256 price; // price for the song / per day, unit is wei(1 ether = 10^18 wei) 
        StakeInfo[] stakeInfo; 
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

    struct Voting {
        uint256 demoID;
        uint256 totalDonationAmount; // total donation amount for the demo
        uint256 totalVoteAmount; // total voted amount (the voting power depends on their previous donation) for the semi-final song
        uint256 votingEndTime; // voting end time
        mapping(address => bool) hasVoted; // listener address => voted or not
    }

    mapping(address => UserType) public identifyUser;

    mapping(address => Artist) allArtists;
    mapping(address => Listener) allListeners;
    mapping(address => Platform) allPlatforms;
    mapping(uint256 => Song) allSongs;
    mapping(uint256 => Demo) allDemos;
    mapping(uint256 => Voting) allVoting; 
    mapping(uint256 => Song) allSongsbeforeVoting; // Temporary storage for songs before voting
    mapping(address => uint256[]) public listenerOwnedSongs;
    mapping(uint256 => uint256[]) public artistToDemos;

    mapping(string => bool) musicHashUsed; // including song hash and demo hash
    
    mapping(uint256 => uint256[]) public artistToSongs; // artistID -> songIDs
    mapping(uint256 => uint256[]) public artistToSemiSongs; // artistID -> songIDs before voting
    mapping(uint256 => Donation[]) donationListenerRecord; // demoId => list of donations
    mapping(uint256 => uint256[]) public platformToSongs; // platformID -> songIDs

    // extra mappings for intellectual property protection
    mapping(uint256 => uint256) timesSongPublished;
    mapping(uint256 => uint256) timesDemoPublished;

    function getDemosByArtist(uint256 _artistID) public view returns (uint256[] memory) {
    return artistToDemos[_artistID];
    }

    function getDemoCount() public view returns (uint256) {
        return demoIDTracker;
    }


    function getDemoDetails(uint256 _demoID) public view returns (
        string memory,  // demoName
        string memory,  // artistName
        string memory,  // genre
        uint256,        // DonationDays
        string memory   // ipfsHash
    ) {
        require(allDemos[_demoID].demoID != 0, "Demo does not exist.");
        Demo memory d = allDemos[_demoID];
        return (d.demoName, d.artistName, d.genre, d.DonationDays, d.ipfsHash);
    }
    
    function getUserType(address _user) public view returns (UserType) {
        return identifyUser[_user];
    }
    function getArtistDetails() public view returns (string memory, uint256, uint256[] memory) {
    require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
    Artist memory artist = allArtists[msg.sender];
    uint256[] memory songs = artistToSongs[artist.artistID];
    return (artist.artistname, artist.artistID, songs);
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

    function getNumSongs() public view returns (uint256) {
    return songIDTracker;
}


    function getListenerDetails() public view returns (
    string memory,    // listener name
    uint256,          // listener ID
    uint256[] memory  // owned song IDs
) {
    require(identifyUser[msg.sender] == UserType.LISTENER, "Not a listener.");
    Listener memory user = allListeners[msg.sender];
    uint256[] memory purchasedSongs = listenerOwnedSongs[msg.sender];
    return (user.name, user.listenerID, purchasedSongs);
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
        newDemo.finalSongPublished = false; // Initialize to false
        allDemos[demoIDTracker] = newDemo;
        
        musicHashUsed[_ipfshash] = true;
        artistToDemos[allArtists[msg.sender].artistID].push(demoIDTracker);
        timesDemoPublished[demoIDTracker] = block.timestamp;
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
        require(allDemos[_demoID].finalSongPublished == false, "The song has been published.");
        require(block.timestamp < timesDemoPublished[_demoID] + allDemos[_demoID].DonationDays * 1 days, "Donation period has ended.");

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

    // return money to the listener if the song is not published after the donation days
    // but the function can only be called after the donation days and should be called by the listener
    function returnDonation(uint256 _demoID) public {
        require(identifyUser[msg.sender] == UserType.LISTENER, "Not a listener.");
        require(allDemos[_demoID].demoID != 0, "Demo does not exist."); // if song published, the demo will be deleted
        require(allDemos[_demoID].finalSongPublished == false, "The song has been published.");

        for (uint256 i = 0; i < donationListenerRecord[_demoID].length; i++) {
            if (donationListenerRecord[_demoID][i].listenerAddress == msg.sender) {
                donationListenerRecord[_demoID][i].listenerAddress.transfer(donationListenerRecord[_demoID][i].donationAmount);
                delete donationListenerRecord[_demoID][i];
            }
        }
    }


// Logic for Voting
// before the song is added, the song is stored in allsongsbeforevoting temporarily, and should be voted by the listener
// the voting will be passed if the donation amount is greater than 50% of the total donation amount
// if passed, the song will be added and the donation will be distributed to the artist
// if not passed, the donation will be returned to the listener and the demo will not be deleted, 
// and there will no be any stakeinfo for the song

    // if donation amount is 0, the song do not need to be voted so that it can skip this process
    function addSongBeforeVoting(
        uint256 _demoID,
        string memory _songName,
        string memory _genre,
        string memory _ipfshash
    ) public {
        require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
        require(allDemos[_demoID].demoID != 0, "Demo does not exist.");
        require(!musicHashUsed[_ipfshash], "Duplicate hash has been detected.");
        require(allDemos[_demoID].artistID == allArtists[msg.sender].artistID, "Not the owner of the demo.");
        require(donationListenerRecord[_demoID].length > 0, "No donations found for this demo.");


        allDemos[_demoID].finalSongPublished = true; // Mark the demo as final song published

        semiSongIDTracker += 1;

        Song memory newSong;
        newSong.songName = _songName;
        newSong.artistName = allArtists[msg.sender].artistname;
        newSong.artistID = allArtists[msg.sender].artistID;
        newSong.genre = _genre;
        newSong.songID = semiSongIDTracker;
        newSong.artistAddress = allArtists[msg.sender].artistAddress;
        newSong.ipfsHash = _ipfshash;
        newSong.price = 0; // Set initial price to 0, can be updated later
        newSong.platformAuthorized = new uint256[](0); // Initialize empty array for authorized platforms
        

        // Store the song temporarily before voting
        allSongsbeforeVoting[semiSongIDTracker] = newSong;

        musicHashUsed[_ipfshash] = true;
        artistToSemiSongs[allArtists[msg.sender].artistID].push(semiSongIDTracker);

        // Create a voting structure and start voting
        Voting storage newVoting = allVoting[semiSongIDTracker];
        newVoting.demoID = _demoID;
        newVoting.votingEndTime = block.timestamp + 7 days;  // Set voting duration
        totalDonationAmount = 0;
        
        for (uint256 i = 0; i < donationListenerRecord[_demoID].length; i++) {
            totalDonationAmount += donationListenerRecord[_demoID][i].donationAmount;
        }
        newVoting.totalDonationAmount = totalDonationAmount;
        
        emit songAddedBeforeVoting(semiSongIDTracker, _songName, _ipfshash);
        
    }
    
    // Event for song voting result
    event songVotingResult(uint256 semisongID, bool isApproved, uint256 votePercentage);

    // Function to vote on a song
    function voteOnSong(uint256 _semisongID) public {
        require(identifyUser[msg.sender] == UserType.LISTENER, "Not a listener.");
        require(allSongsbeforeVoting[_semisongID].songID != 0, "Song does not exist in voting.");
        require(allVoting[_semisongID].votingEndTime > block.timestamp, "Voting has ended.");
        require(!allVoting[_semisongID].hasVoted[msg.sender], "You have already voted.");
        require(donationListenerRecord[allVoting[_semisongID].demoID].length > 0, "No donations found for this demo.");
        uint256 donatorIndex = -1;
        bool isDonator = false;
        for (uint256 i = 0; i < donationListenerRecord[allVoting[_semisongID].demoID].length; i++) {
            if (donationListenerRecord[allVoting[_semisongID].demoID][i].listenerAddress == msg.sender) {
                isDonator = true;
                donatorIndex = i;
                break;
            }
        }
        require(isDonator, "You are not the donator of the demo.");


        // Record the listener's previous donation (standing for vote amount)
        allVoting[_semisongID].hasVoted[msg.sender] = true;
        donationAmount = donationListenerRecord[allVoting[_semisongID].demoID][donatorIndex].donationAmount;
        allVoting[_semisongID].totalVoteAmount += donationAmount;
    }

    // Function to finalize voting and move song to final list if approved
    function finalizeSongVoting(uint256 _semisongID) public {
        require(allSongsbeforeVoting[_semisongID].songID != 0, "Song does not exist in voting.");
        require(block.timestamp > allVoting[_semisongID].votingEndTime, "Voting is still ongoing.");

        uint256 totalVoteAmount = allVoting[_semisongID].totalVoteAmount;
        uint256 totalDonationAmount = allVoting[_semisongID].totalDonationAmount;
        uint256 requiredDonationAmount = totalDonationAmount * 50 / 100;  // Example threshold

        // Move song to final songs
        songIDTracker += 1;
        _songID = songIDTracker;

        Song memory finalSong = allSongsbeforeVoting[_semisongID];
        allSongs[songIDTracker] = finalSong;

        
        // Voting passed 
        if (totalVoteAmount >= requiredDonationAmount) {

            // Distribute donations to artist 
            allSongs[_songID].artistAddress.transfer(totalDonationAmount);
            // Add stake info to the song
            StakeInfo = new StakeInfo[](donationListenerRecord[allVoting[_semisongID].demoID].length);
            for (uint256 i = 0; i < donationListenerRecord[allVoting[_semisongID].demoID].length; i++) {
                StakeInfo[i] = StakeInfo({
                    StakeProportion: donationListenerRecord[allVoting[_semisongID].demoID][i].donationAmount * 100 / totalDonationAmount,
                    listenerAddress: donationListenerRecord[allVoting[_semisongID].demoID][i].listenerAddress
                });
                listenerOwnedSongs[donationListenerRecord[allVoting[_semisongID].demoID][i].listenerAddress].push(_songID);

            }
            allSongs[songIDTracker].stakeInfo = StakeInfo;

            emit songVotingResult(_songID, true, totalVoteAmount/totalDonationAmount);
        } else {
            // Voting failed, refund donations to listeners
            // No stake info will be added to the song
            for (uint256 i = 0; i < donationListenerRecord[_songID].length; i++) {
                donationListenerRecord[_songID][i].listenerAddress.transfer(donationListenerRecord[_songID][i].donationAmount);
            }            
            emit songVotingResult(_songID, false, totalVoteAmount/totalDonationAmount);
        }

        // Clear and update record
        delete allSongsbeforeVoting[_semisongID];
        delete donationListenerRecord[allVoting[_semisongID].demoID];
        
        artistToSemiSongs[allSongsbeforeVoting[_semisongID].artistID].remove(_semisongID);
        artistToSongs[allSongsbeforeVoting[_semisongID].artistID].push(_songID);
    }        

// End of Voting Logic    

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
        require(msg.value > allSongs[_songID].price * _purchaseDays, "Purchase amount must be greater than the price.");
        require(_purchaseDays > 0, "Purchase days must be greater than 0.");

        // add the song to the platform
        platformToSongs[_platformID].push(_songID);
        // add the platform to the song
        allSongs[_songID].platformAuthorized.push(_platformID);

        // calculate the shares owned by the listener, and the default is 90% to the artist and 10% to the listener
        if (allSongs[_songID].stakeInfo.length == 0) {
            // if there is no stake info, the song is not published yet, so the artist will get 100% of the purchase amount
            allSongs[_songID].artistAddress.transfer(msg.value);
            emit platformPurchase(
                _songID,
                allSongs[_songID].songName,
                allSongs[_songID].artistName,
                allPlatforms[msg.sender].platformID,
                allPlatforms[msg.sender].name,
                msg.value,
                _purchaseDays
            );
            return;
        }
        uint256 artistShare = msg.value * 90 / 100;
        uint256 listenerShare = msg.value * 10 / 100;
        // transfer the purchase amount to the artist
        allSongs[_songID].artistAddress.transfer(artistShare);

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
            msg.value,
            _purchaseDays
        );
    }

    // unauthorize the platform to publish the song after expiration 
    // call by artist or platform
    event platformUnauthorize(
        uint256 songID,
        string songName,
        string artistName,
        uint256 platformID,
        string platformName);
    function unauthorizePlatform(
        uint256 _songID,
        uint256 _platformID) public {
        require(identifyUser[msg.sender] == UserType.ARTIST || identifyUser[msg.sender] == UserType.PLATFORM, "Not an artist or platform.");
        require(allSongs[_songID].songID != 0, "Song does not exist.");
        require(allPlatforms[msg.sender].platformID == _platformID, "Not the owner of the platform.");

        for (uint256 i = 0; i < allSongs[_songID].platformAuthorized.length; i++) {
            if (allSongs[_songID].platformAuthorized[i] == _platformID) {
                delete allSongs[_songID].platformAuthorized[i];
            }
        }

        emit platformUnauthorize(
            _songID,
            allSongs[_songID].songName,
            allSongs[_songID].artistName,
            _platformID,
            allPlatforms[msg.sender].name
        );
    }