// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SignalDAO
 * @dev A decentralized autonomous organization for trading signal coordination
 * @author SignalDAO Team
 */
contract SignalDAO {
    
    // Structs
    struct Signal {
        uint256 id;
        address provider;
        string asset;
        string direction; // "BUY" or "SELL"
        uint256 targetPrice;
        uint256 timestamp;
        uint256 votes;
        bool isActive;
        mapping(address => bool) hasVoted;
    }
    
    struct Member {
        bool isActive;
        uint256 reputation;
        uint256 signalsProvided;
        uint256 joinedAt;
    }
    
    // State variables
    mapping(address => Member) public members;
    mapping(uint256 => Signal) public signals;
    
    uint256 public signalCounter;
    uint256 public totalMembers;
    uint256 public constant MIN_REPUTATION = 10;
    uint256 public constant VOTING_PERIOD = 24 hours;
    
    address public owner;
    
    // Events
    event MemberJoined(address indexed member, uint256 timestamp);
    event SignalCreated(uint256 indexed signalId, address indexed provider, string asset, string direction);
    event SignalVoted(uint256 indexed signalId, address indexed voter, uint256 totalVotes);
    event ReputationUpdated(address indexed member, uint256 newReputation);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyMember() {
        require(members[msg.sender].isActive, "Only active members can call this function");
        _;
    }
    
    modifier validSignal(uint256 _signalId) {
        require(_signalId > 0 && _signalId <= signalCounter, "Invalid signal ID");
        require(signals[_signalId].isActive, "Signal is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        signalCounter = 0;
        totalMembers = 0;
        
        // Owner automatically becomes first member
        members[owner] = Member({
            isActive: true,
            reputation: 100,
            signalsProvided: 0,
            joinedAt: block.timestamp
        });
        totalMembers = 1;
        
        emit MemberJoined(owner, block.timestamp);
    }
    
    /**
     * @dev Core Function 1: Join the DAO as a new member
     * @notice Allows new users to join the SignalDAO community
     */
    function joinDAO() external {
        require(!members[msg.sender].isActive, "Already a member");
        
        members[msg.sender] = Member({
            isActive: true,
            reputation: MIN_REPUTATION,
            signalsProvided: 0,
            joinedAt: block.timestamp
        });
        
        totalMembers++;
        emit MemberJoined(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Create a new trading signal
     * @param _asset The trading asset (e.g., "BTC/USDT")
     * @param _direction Trading direction ("BUY" or "SELL")
     * @param _targetPrice Target price for the signal
     */
    function createSignal(
        string memory _asset,
        string memory _direction,
        uint256 _targetPrice
    ) external onlyMember {
        require(bytes(_asset).length > 0, "Asset cannot be empty");
        require(
            keccak256(abi.encodePacked(_direction)) == keccak256(abi.encodePacked("BUY")) ||
            keccak256(abi.encodePacked(_direction)) == keccak256(abi.encodePacked("SELL")),
            "Direction must be BUY or SELL"
        );
        require(_targetPrice > 0, "Target price must be greater than 0");
        
        signalCounter++;
        
        Signal storage newSignal = signals[signalCounter];
        newSignal.id = signalCounter;
        newSignal.provider = msg.sender;
        newSignal.asset = _asset;
        newSignal.direction = _direction;
        newSignal.targetPrice = _targetPrice;
        newSignal.timestamp = block.timestamp;
        newSignal.votes = 0;
        newSignal.isActive = true;
        
        members[msg.sender].signalsProvided++;
        
        emit SignalCreated(signalCounter, msg.sender, _asset, _direction);
    }
    
    /**
     * @dev Core Function 3: Vote on a trading signal
     * @param _signalId The ID of the signal to vote on
     * @notice Members can vote on signals to show confidence
     */
    function voteOnSignal(uint256 _signalId) external onlyMember validSignal(_signalId) {
        Signal storage signal = signals[_signalId];
        
        require(!signal.hasVoted[msg.sender], "Already voted on this signal");
        require(
            block.timestamp <= signal.timestamp + VOTING_PERIOD,
            "Voting period has ended"
        );
        require(signal.provider != msg.sender, "Cannot vote on your own signal");
        
        signal.hasVoted[msg.sender] = true;
        signal.votes++;
        
        // Increase reputation of signal provider based on votes
        if (signal.votes % 5 == 0) {
            members[signal.provider].reputation += 2;
            emit ReputationUpdated(signal.provider, members[signal.provider].reputation);
        }
        
        emit SignalVoted(_signalId, msg.sender, signal.votes);
    }
    
    // View functions
    function getSignalDetails(uint256 _signalId) external view returns (
        address provider,
        string memory asset,
        string memory direction,
        uint256 targetPrice,
        uint256 timestamp,
        uint256 votes,
        bool isActive
    ) {
        require(_signalId > 0 && _signalId <= signalCounter, "Invalid signal ID");
        Signal storage signal = signals[_signalId];
        
        return (
            signal.provider,
            signal.asset,
            signal.direction,
            signal.targetPrice,
            signal.timestamp,
            signal.votes,
            signal.isActive
        );
    }
    
    function getMemberInfo(address _member) external view returns (
        bool isActive,
        uint256 reputation,
        uint256 signalsProvided,
        uint256 joinedAt
    ) {
        Member storage member = members[_member];
        return (
            member.isActive,
            member.reputation,
            member.signalsProvided,
            member.joinedAt
        );
    }
    
    function hasVotedOnSignal(uint256 _signalId, address _voter) external view returns (bool) {
        return signals[_signalId].hasVoted[_voter];
    }
    
    // Admin functions
    function deactivateSignal(uint256 _signalId) external onlyOwner validSignal(_signalId) {
        signals[_signalId].isActive = false;
    }
    
    function updateMemberReputation(address _member, uint256 _newReputation) external onlyOwner {
        require(members[_member].isActive, "Member is not active");
        members[_member].reputation = _newReputation;
        emit ReputationUpdated(_member, _newReputation);
    }
}
