// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract VibeStake {

    uint256 artistIDTracker;
    uint256 listenerIDTracker;
    uint256 platformIDTracker;
    uint256 demoIDTracker;
    uint256 songIDTracker;
    uint256 semiSongIDTracker; // for the song before voting
    uint256 commission_fee = 10; // 10% commission fee for the DApp platform

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
        string artistName;
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
        address platformAddress;
        uint256 copyRightPayment; 
    }

    struct Demo {
        string demoName;
        address artistAddress; // artist address
        string genre;
        uint256 demoID;
        uint256 DonationDays; // promise final song will be published within this time
        string ipfsHash; // IPFS address for storing demo
        bool finalSongPublished; // whether the song is published or not
    }

    struct Song {
        string songName;
        string genre;
        uint256 songID;
        address payable artistAddress;
        uint256 [] platformAuthorized; // platformID 
        string ipfsHash; // IPFS address for storing song
        uint256 price; // price for the song / per day, unit is wei(1 ether = 10^18 wei) 
    }

    struct StakeInfo{
        uint256 StakeProportion; // 0-100
        address payable listenerAddress;
    }

    struct Donation {
        uint256 DemoID;
        uint256 donationAmount;
        address payable listenerAddress;
    }
    
    struct Voting {
        uint256 demoID;
        uint256 totalDonationAmount; // total donated amount for the demo
        uint256 totalVoteAmount; // total voted amount (the voting power depends on their previous donation) for the semi-final song
        uint256 votingEndTime; // voting end time
        mapping(address => bool) hasVoted; // listener address => voted or not
    }

    struct Ownership {
        uint256 songID;
        uint256 expirTime; // expiration time of the song
    }

    mapping(address => UserType) public identifyUser; // user address => user type(ARTIST, LISTENER, PLATFORM)

    address[] public artistsList; // list of artists
    address[] public listenersList; // list of listeners
    address[] public platformsList; // list of platforms
    mapping(uint256 => address) public artistIDToAddress; // artist ID => artist address
    mapping(uint256 => address) public listenerIDToAddress; // listener ID => listener address
    mapping(uint256 => address) public platformIDToAddress; // platform ID => platform address

    mapping(address => Artist) allArtists;
    mapping(address => Listener) allListeners;
    mapping(address => Platform) allPlatforms;
    mapping(uint256 => Demo) allDemos;
    mapping(uint256 => Voting) allVoting; 
    mapping(uint256 => Song) allSongsbeforeVoting; // Temporary storage for songs before voting
    mapping(uint256 => Song) allSongs;

    mapping(string => bool) musicHashUsed; // including demo hash

    // mapping for artist and his music    
    mapping(uint256 => uint256[]) public artistToDemos;
    mapping(uint256 => uint256[]) public artistToSemiSongs; // artistID -> songIDs before voting
    mapping(uint256 => uint256[]) public artistToSongs; // artistID -> songIDs

    // mapping for listener and his music
    mapping(uint256 => Donation[]) donationListenerRecord; // demoId => list of donations
    mapping(address => uint256[]) public listenerOwnedSongs;

    // mapping for platform and his music
    mapping(uint256 => Ownership[]) public platformToSongs; // platformID -> (songID, expiration time)

    // mapping for user and his profit including artist and listener
    mapping(address => uint256) public userProfit; // user address => profit amount

    // mapping for song and his stake info
    mapping (uint256 => StakeInfo[]) public songToStakeInfo;

    // extra mappings for intellectual property protection
    mapping(uint256 => uint256) timesSongPublished;
    mapping(uint256 => uint256) timesDemoPublished;

    
    function getUserType(address _user) public view returns (UserType) {
        return identifyUser[_user];
    }

    function registerArtist(string memory _name) public {
        require(identifyUser[msg.sender] == UserType.UNDEFINED, "User already registered.");

        artistIDTracker++;
        identifyUser[msg.sender] = UserType.ARTIST;
        allArtists[msg.sender] = Artist(_name, artistIDTracker, payable(msg.sender));
        artistsList.push(msg.sender); // Add the artist to the list of artists
        artistIDToAddress[artistIDTracker] = msg.sender; // Map artist ID to address
    }

    function registerListener(string memory _name) public {
        require(identifyUser[msg.sender] == UserType.UNDEFINED, "User already registered.");
        listenerIDTracker++;
        identifyUser[msg.sender] = UserType.LISTENER;
        allListeners[msg.sender] = Listener(_name, listenerIDTracker);
        listenersList.push(msg.sender); // Add the listener to the list of listeners
        listenerIDToAddress[listenerIDTracker] = msg.sender; // Map listener ID to address
    }

    function registerPlatform(string memory _name) public {
        require(identifyUser[msg.sender] == UserType.UNDEFINED, "User already registered.");
        platformIDTracker++;
        identifyUser[msg.sender] = UserType.PLATFORM;
        allPlatforms[msg.sender] = Platform(_name, platformIDTracker, msg.sender, 0);
        platformsList.push(msg.sender); // Add the platform to the list of platforms
        platformIDToAddress[platformIDTracker] = msg.sender; // Map platform ID to address
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
        newDemo.artistAddress = msg.sender;
        newDemo.genre = _genre;
        newDemo.demoID = demoIDTracker;
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
            allArtists[msg.sender].artistName,
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
    function donateToDemo(uint256 _demoID) public payable {
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
    // but the function can only be called before the song is published
    // the donation will be returned to the listener according to their donation amount but the commission fee will be deducted
    function returnDonation(uint256 _demoID) public {
        require(identifyUser[msg.sender] == UserType.LISTENER, "Not a listener.");
        require(allDemos[_demoID].demoID != 0, "Demo does not exist."); // if song published, the demo will be deleted
        require(allDemos[_demoID].finalSongPublished == false, "The song has been published.");

        for (uint256 i = 0; i < donationListenerRecord[_demoID].length; i++) {
            if (donationListenerRecord[_demoID][i].listenerAddress == msg.sender) {
                donationListenerRecord[_demoID][i].listenerAddress.transfer(donationListenerRecord[_demoID][i].donationAmount* (100-commission_fee) / 100);
                delete donationListenerRecord[_demoID][i];
            }
        }
    }


// Logic for Voting
// before the song is added, the song is stored in allsongsbeforevoting temporarily, and should be voted by the donators
// the voting will be passed if the donation amount is greater than 50% of the total donation amount
// if passed, the song will be added and the donation will be distributed to the artist
// if not passed, the donation will be returned to the listener and the demo will not be deleted, 
// and there will no be any stakeinfo for the song

    // if no donation, the song will be published directly
    event SongPublished(
        uint256 demoID,
        uint256 songID,
        string artistName,
        string songName,
        string genre,
        string ipfshash
    );
    function publishSong(uint256 _demoID,
        string memory _songName,
        string memory _genre,
        string memory _ipfshash
        ) public {
        require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
        require(allDemos[_demoID].demoID != 0, "Demo does not exist.");
        require(allDemos[_demoID].artistAddress == msg.sender, "Not the owner of the demo.");
        require(allDemos[_demoID].finalSongPublished == false, "The song has been published.");
        require(donationListenerRecord[_demoID].length == 0, "The song should be voted before publishing.");
        require(!musicHashUsed[_ipfshash], "Duplicate hash has been detected.");

        songIDTracker += 1;
        allDemos[_demoID].finalSongPublished = true; // Mark the demo as final song published

        Song memory newSong;
        newSong.songName = _songName;
        newSong.genre = _genre;
        newSong.songID = songIDTracker;
        newSong.artistAddress = allArtists[msg.sender].artistAddress;
        newSong.ipfsHash = _ipfshash;
        newSong.price = 0; // Set initial price to 0, can be updated later
        newSong.platformAuthorized = new uint256[](0); // Initialize empty array for authorized platforms
        
        allSongs[songIDTracker] = newSong;

        musicHashUsed[_ipfshash] = true;
        artistToSongs[allArtists[msg.sender].artistID].push(songIDTracker);
        timesSongPublished[songIDTracker] = block.timestamp; // Store the time when the song is published

        emit SongPublished(
            _demoID,
            songIDTracker,
            allArtists[msg.sender].artistName,
            _songName,
            _genre,
            _ipfshash
        );
    }



    event SongSubmitted(
        uint256 demoID,
        uint256 semiSongID,
        string artistName,
        string songName,
        string genre,
        string ipfshash
    );
    // if donation amount is 0, the song do not need to be voted so that it can skip this process
    function submitSongsForVoting(
        uint256 _demoID,
        string memory _songName,
        string memory _genre,
        string memory _ipfshash
    ) public {
        require(identifyUser[msg.sender] == UserType.ARTIST, "Not an artist.");
        require(allDemos[_demoID].demoID != 0, "Demo does not exist.");
        require(!musicHashUsed[_ipfshash], "Duplicate hash has been detected.");
        require(allDemos[_demoID].artistAddress == msg.sender, "Not the owner of the demo.");
        require(donationListenerRecord[_demoID].length > 0, "No donations found for this demo.");


        allDemos[_demoID].finalSongPublished = true; // Mark the demo as final song published

        semiSongIDTracker += 1;

        Song memory newSong;
        newSong.songName = _songName;
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
        uint256 totalDonationAmount = 0;
        
        for (uint256 i = 0; i < donationListenerRecord[_demoID].length; i++) {
            totalDonationAmount += donationListenerRecord[_demoID][i].donationAmount;
        }
        newVoting.totalDonationAmount = totalDonationAmount;

        emit SongSubmitted(
            _demoID,
            semiSongIDTracker,
            allArtists[msg.sender].artistName,
            _songName,
            _genre,
            _ipfshash
        );
        
    }
    

    event songVotingUpdate(
        uint256 semisongID,
        string songName,
        string artistName,
        uint256 demoID,
        uint256 VoteAmount,
        uint256 totalVotePercentage);

    // Function to vote on a song
    function voteOnSong(uint256 _semisongID) public {
        require(identifyUser[msg.sender] == UserType.LISTENER, "Not a listener.");
        require(allSongsbeforeVoting[_semisongID].songID != 0, "Song does not exist in voting.");
        require(allVoting[_semisongID].votingEndTime > block.timestamp, "Voting has ended.");
        require(!allVoting[_semisongID].hasVoted[msg.sender], "You have already voted.");
        require(donationListenerRecord[allVoting[_semisongID].demoID].length > 0, "No donations found for this demo.");
        uint256 donatorIndex;
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
        uint256 donationAmount = donationListenerRecord[allVoting[_semisongID].demoID][donatorIndex].donationAmount;
        allVoting[_semisongID].totalVoteAmount += donationAmount;
        emit songVotingUpdate(
            _semisongID,
            allSongsbeforeVoting[_semisongID].songName,
            allArtists[allSongsbeforeVoting[_semisongID].artistAddress].artistName,
            allVoting[_semisongID].demoID,
            donationAmount,
            allVoting[_semisongID].totalVoteAmount * 100 / allVoting[_semisongID].totalDonationAmount
        );
    }
    
    // Event for song voting result
    event songVotingResult(uint256 semisongID, bool isApproved, uint256 votePercentage);
    // Function to finalize voting and move song to final list if approved
    function finalizeSongVoting(uint256 _semisongID) public {
        require(allSongsbeforeVoting[_semisongID].songID != 0, "Song does not exist in voting.");
        require(block.timestamp > allVoting[_semisongID].votingEndTime, "Voting is still ongoing.");

        uint256 totalVoteAmount = allVoting[_semisongID].totalVoteAmount;
        uint256 totalDonationAmount = allVoting[_semisongID].totalDonationAmount;
        uint256 requiredDonationAmount = totalDonationAmount * 50 / 100;  // Example threshold

        // Move song to final songs
        songIDTracker += 1;
        uint256 _songID = songIDTracker;

        Song memory finalSong = allSongsbeforeVoting[_semisongID];
        allSongs[songIDTracker] = finalSong;

        
        // Voting passed 
        if (totalVoteAmount >= requiredDonationAmount) {

            // Distribute 90% donations to artist 
            allSongs[_songID].artistAddress.transfer(totalDonationAmount * (100-commission_fee) / 100);
            userProfit[allSongs[_songID].artistAddress] += totalDonationAmount * (100-commission_fee) / 100;
            
            
            // Add stake info to the song
            for (uint256 i = 0; i < donationListenerRecord[allVoting[_semisongID].demoID].length; i++) {
                songToStakeInfo[_songID].push(StakeInfo({
                    StakeProportion: donationListenerRecord[allVoting[_semisongID].demoID][i].donationAmount * 100 / totalDonationAmount,
                    listenerAddress: donationListenerRecord[allVoting[_semisongID].demoID][i].listenerAddress
                }));
                listenerOwnedSongs[donationListenerRecord[allVoting[_semisongID].demoID][i].listenerAddress].push(_songID);

            }
            

            emit songVotingResult(_songID, true, totalVoteAmount/totalDonationAmount);
        } else {
            // Voting failed, refund donations to listeners
            // No stake info will be added to the song
            for (uint256 i = 0; i < donationListenerRecord[_songID].length; i++) {
                donationListenerRecord[_songID][i].listenerAddress.transfer(donationListenerRecord[_songID][i].donationAmount* (100-commission_fee) / 100);
            }            
            emit songVotingResult(_songID, false, totalVoteAmount/totalDonationAmount);
        }

        // Clear and update record
        delete allSongsbeforeVoting[_semisongID];
        delete donationListenerRecord[allVoting[_semisongID].demoID];
        
        // Remove the song from the artistToSemiSongs mapping
        uint256 _artistID = allArtists[allSongsbeforeVoting[_semisongID].artistAddress].artistID;
        uint256[] storage semiSongs = artistToSemiSongs[_artistID];
        for (uint256 i = 0; i < semiSongs.length; i++) {
            if (semiSongs[i] == _semisongID) {
                semiSongs[i] = semiSongs[semiSongs.length - 1];
                semiSongs.pop();
                break;
            }
        }
        artistToSongs[_artistID].push(_songID);
    }        

// End of Voting Logic    

    // platform purchase the right to publish the song for certain days
    event platformPurchase(
        uint256 songID,
        string songName,
        string artistName,
        uint256 platformID,
        string platformName,
        uint256 purchaseAmount, // msg.value
        uint256 purchaseDays);

    function purchaseSong (
        uint256 _songID,
        uint256 _purchaseDays) public payable{
        require(identifyUser[msg.sender] == UserType.PLATFORM, "Not a platform.");
        require(allSongs[_songID].songID != 0, "Song does not exist.");
        require(msg.value > allSongs[_songID].price * _purchaseDays, "Purchase amount must be greater than the price.");
        require(_purchaseDays > 0, "Purchase days must be greater than 0.");

        allPlatforms[msg.sender].copyRightPayment += msg.value * (100-commission_fee) / 100; // add the purchase amount to the platform's profit
        
        // if the platform has already purchased the song, the purchase amount will be added to the previous purchase amount
        for (uint256 i = 0; i < allSongs[_songID].platformAuthorized.length; i++) {
            if (allSongs[_songID].platformAuthorized[i] == allPlatforms[msg.sender].platformID) {
                allSongs[_songID].price += msg.value * (100-commission_fee) / 100;
                userProfit[allPlatforms[msg.sender].platformAddress] += msg.value * (100-commission_fee) / 100;
                platformToSongs[allPlatforms[msg.sender].platformID][i].expirTime += _purchaseDays * 1 days; // Extend expiration time
                return;
            }
        }

        // add the song to the platform
        uint256 _platformID = allPlatforms[msg.sender].platformID;
        Ownership memory newOwnership;
        newOwnership.songID = _songID;
        newOwnership.expirTime = block.timestamp + _purchaseDays * 1 days; // Set expiration time
        platformToSongs[_platformID].push(newOwnership);
        // add the platform to the song
        allSongs[_songID].platformAuthorized.push(_platformID);

        // calculate the shares owned by the listener, and the default is 80% to the artist and 10% to the listener, 10% to the platform
        if (songToStakeInfo[_songID].length == 0) {
            // if there is no stake info, the song is not published yet, so the artist will get 100% of the purchase amount
            allSongs[_songID].artistAddress.transfer(msg.value* (100-commission_fee) / 100);
            userProfit[allSongs[_songID].artistAddress] += msg.value* (100-commission_fee) / 100;
            emit platformPurchase(
                _songID,
                allSongs[_songID].songName,
                allArtists[allSongs[_songID].artistAddress].artistName,
                allPlatforms[msg.sender].platformID,
                allPlatforms[msg.sender].name,
                msg.value,
                _purchaseDays
            );
            return;
        }
        uint256 artistShare = msg.value * (100-commission_fee-10) / 100;
        uint256 listenerShare = msg.value * 10 / 100;
        // transfer the purchase amount to the artist
        allSongs[_songID].artistAddress.transfer(artistShare);
        userProfit[allSongs[_songID].artistAddress] += artistShare;

        // transfer the listener share to the listener according to their donation amount
        for (uint256 i = 0; i < songToStakeInfo[_songID].length; i++) {
            uint256 listenerShareAmount = listenerShare * songToStakeInfo[_songID][i].StakeProportion / 100;
            songToStakeInfo[_songID][i].listenerAddress.transfer(listenerShareAmount);
            userProfit[songToStakeInfo[_songID][i].listenerAddress] += listenerShareAmount;
        }
        
        
        emit platformPurchase(
            _songID,
            allSongs[_songID].songName,
            allArtists[allSongs[_songID].artistAddress].artistName,
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
        require(allSongs[_songID].platformAuthorized.length > 0, "No platform authorized.");
        require(block.timestamp > platformToSongs[_platformID][0].expirTime, "The song is still authorized.");

        for (uint256 i = 0; i < allSongs[_songID].platformAuthorized.length; i++) {
            if (allSongs[_songID].platformAuthorized[i] == _platformID) {
                delete allSongs[_songID].platformAuthorized[i];
            }
        }
        // Remove the song from the platform's ownership list
        for (uint256 i = 0; i < platformToSongs[_platformID].length; i++) {
            if (platformToSongs[_platformID][i].songID == _songID) {
                delete platformToSongs[_platformID][i];
            }
        }


        emit platformUnauthorize(
            _songID,
            allSongs[_songID].songName,
            allArtists[allSongs[_songID].artistAddress].artistName,
            _platformID,
            allPlatforms[msg.sender].name
        );
    }
    
    // accessibility: public
    // get general info of the smart contract
    function getHistoryNumArtists() public view returns (uint256) {
        return artistIDTracker;
    }
    function getHistoryNumListeners() public view returns (uint256) {
        return listenerIDTracker;
    }
    function getHistoryNumPlatforms() public view returns (uint256) {
        return platformIDTracker;
    }
    function getHistoryNumDemos() public view returns (uint256) {
        return demoIDTracker;
    }
    function getHistoryNumSongs() public view returns (uint256) {
        return songIDTracker;
    }

    // get simple list of artists/platforms/demos/songs
    function getListArtists() public view returns (string[] memory, uint256[] memory) {
        uint256 totalArtists = artistIDTracker;
        string[] memory artistNames = new string[](totalArtists);
        uint256[] memory artistIDs = new uint256[](totalArtists);

        uint256 index = 0;
        for (uint256 i = 0; i < artistsList.length; i++) {
            address artistAddress = artistsList[i];
            artistNames[index] = allArtists[artistAddress].artistName;
            artistIDs[index] = allArtists[artistAddress].artistID;
            index++;
        }

        return (artistNames, artistIDs);
    }
    function getListPlatforms() public view returns (string[] memory, uint256[] memory) {
        uint256 totalPlatforms = platformIDTracker;
        string[] memory platformNames = new string[](totalPlatforms);
        uint256[] memory platformIDs = new uint256[](totalPlatforms);

        uint256 index = 0;
        for (uint256 i = 0; i < platformsList.length; i++) {
            address platformAddress = platformsList[i];
            platformNames[index] = allPlatforms[platformAddress].name;
            platformIDs[index] = allPlatforms[platformAddress].platformID;
            index++;
        }
        
        return (platformNames, platformIDs);
    }
    function getListDemos() public view returns (string[] memory, uint256[] memory) {
        uint256 totalDemos = demoIDTracker;
        string[] memory demoNames = new string[](totalDemos);
        uint256[] memory demoIDs = new uint256[](totalDemos);

        uint256 index = 0;
        for (uint256 i = 1; i <= totalDemos; i++) {
            if (allDemos[i].demoID != 0) {
                demoNames[index] = allDemos[i].demoName;
                demoIDs[index] = allDemos[i].demoID;
                index++;
            }
        }

        return (demoNames, demoIDs);
    }
    function getListSongs() public view returns (string[] memory, uint256[] memory) {
        uint256 totalSongs = songIDTracker;
        string[] memory songNames = new string[](totalSongs);
        uint256[] memory songIDs = new uint256[](totalSongs);

        uint256 index = 0;
        for (uint256 i = 1; i <= totalSongs; i++) {
            if (allSongs[i].songID != 0) {
                songNames[index] = allSongs[i].songName;
                songIDs[index] = allSongs[i].songID;
                index++;
            }
        }

        return (songNames, songIDs);
    }

    // get details of listener/artist/platform/demo/song
    // accessibility: private
    function getListenerDetails(uint256 _listenerId) public view returns (string memory, uint256, uint256[] memory) {
        require(msg.sender == listenerIDToAddress[_listenerId], "Not the owner of the listener ID.");

        Listener memory listener = allListeners[listenerIDToAddress[_listenerId]];
        uint256[] memory purchasedSongs = listenerOwnedSongs[listenerIDToAddress[_listenerId]];

        return (listener.name, listener.listenerID, purchasedSongs);
    }
    // accessibility: public
    function getArtistDetails(uint256 _artistId) public view returns (string memory, uint256, uint256[] memory, uint256[] memory, uint256[] memory) {
        require(allArtists[artistIDToAddress[_artistId]].artistID != 0, "Artist does not exist.");

        Artist memory artist = allArtists[artistIDToAddress[_artistId]];
        uint256[] memory ownedDemos = artistToDemos[artist.artistID];
        uint256[] memory ownedSemiSongs = artistToSemiSongs[artist.artistID];
        uint256[] memory ownedSongs = artistToSongs[artist.artistID];

        return (artist.artistName, artist.artistID, ownedDemos, ownedSemiSongs, ownedSongs);
    }
    function getPlatformDetails(uint256 _platformId) public view returns (
        string memory, 
        uint256, 
        uint256[] memory, 
        uint256[] memory,
        uint256) {
        require(allPlatforms[platformIDToAddress[_platformId]].platformID != 0, "Platform does not exist.");

        Platform memory platform = allPlatforms[platformIDToAddress[_platformId]];
        Ownership[] memory allOwnership = platformToSongs[platform.platformID];
        uint256[] memory songsOwned = new uint256[](allOwnership.length);
        uint256[] memory expirTimes = new uint256[](allOwnership.length);
        for (uint256 i = 0; i < allOwnership.length; i++) {
            songsOwned[i] = allOwnership[i].songID;
            expirTimes[i] = allOwnership[i].expirTime;
            
        }
    
        return (platform.name, platform.platformID, songsOwned, expirTimes, platform.copyRightPayment);
        

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
        return (d.demoName, allArtists[d.artistAddress].artistName, d.genre, d.DonationDays, d.ipfsHash);
    }
    function getSongDetails(uint256 _songID) public view returns (
        string memory,  // songName
        string memory,  // artistName
        string memory,  // genre
        uint256,        // price
        string memory   // ipfsHash
    ) {
        require(allSongs[_songID].songID != 0, "Song does not exist.");
        Song memory s = allSongs[_songID];
        return (s.songName, allArtists[s.artistAddress].artistName, s.genre, s.price, s.ipfsHash);
    }

    // Accessibility: user itself
    // get profit of the user
    function getMyProfit() public view returns (uint256) {
        require(identifyUser[msg.sender] != UserType.UNDEFINED, "User not registered.");
        require(userProfit[msg.sender] > 0, "No profit available.");
        return userProfit[msg.sender];
    }


    // get info while in the donation period
    function getDemoDonationDetails(uint256 _demoID) public view returns (
        string memory,  // demoName
        string memory,  // artistName
        uint256,        // DonationEndCountdown in hours
        uint256,        // donationAmount
        string memory   // ipfsHash
    ) {
        require(allDemos[_demoID].demoID != 0, "Demo does not exist.");
        require(allDemos[_demoID].finalSongPublished == false, "The song has been published.");
        Demo memory d = allDemos[_demoID];
        uint256 totalDonationAmount = 0;
        for (uint256 i = 0; i < donationListenerRecord[_demoID].length; i++) {
            totalDonationAmount += donationListenerRecord[_demoID][i].donationAmount;
        }
        uint256 donationEndTime = (timesDemoPublished[_demoID] + d.DonationDays * 1 days - block.timestamp) / 1 hours; // in hours
        return (d.demoName, allArtists[d.artistAddress].artistName, donationEndTime, totalDonationAmount, d.ipfsHash);
    }

    // get info while in the voting period
    function getSongVotingDetails(uint256 _semisongID) public view returns (
        string memory,  // songName
        string memory,  // artistName
        uint256,        // totalVoteAmount
        uint256,        // votingPercentage
        uint256         // votingEndTime
    ) {
        require(allSongsbeforeVoting[_semisongID].songID != 0, "Song does not exist.");
        
        string memory songName = allSongsbeforeVoting[_semisongID].songName;
        string memory artistName = allArtists[allSongsbeforeVoting[_semisongID].artistAddress].artistName;
        uint256 totalVoteAmount = allVoting[_semisongID].totalVoteAmount;
        uint256 totalDonationAmount = allVoting[_semisongID].totalDonationAmount;
        uint256 votingPercentage = totalVoteAmount * 100 / totalDonationAmount;
        uint256 votingEndTime = allVoting[_semisongID].votingEndTime;
        return (songName, artistName, totalVoteAmount, votingPercentage, votingEndTime);
    }



}
