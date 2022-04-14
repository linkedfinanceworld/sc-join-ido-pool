// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract JoinIDOPool is 
        Context,
        Ownable,
        ERC20("LFW Join IDO Pool", "LFW-IDO-Join") 
{

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Fund receiver
    address public fundReceiver;

    // Total amount of BUSD has been used
    uint256 public totalJoined;

    // BUSD Token address
    address public busdToken;

    // join start at which timestamp
    uint256 public joinStartAt;

    // join end at which timestamp
    uint256 public joinEndAt;

    // number of participant has been joined
    uint256 public joinedCount;

    // Maximum allocation amount for pool
    uint256 public maxPoolAllocation;

    // Is the pool initialized yet
    bool public isInitialized; 

    // Mapping isjoined for an address
    mapping(address => bool) public isJoined;

    // user address => pool name => number of slot.
    mapping(address => uint256) public whitelistAddress;

    // user max allocation
    mapping(address => uint256) public userMaxAllocation;

    // how much BUSD user used
    mapping(address => uint256) public userJoinedAmount;

    event EventJoined(
        address indexed sender,
        uint256 amount,
        uint256 date
    );

    /**
     * @notice set new config for the SC
     * @dev only call by owner
     * @param _busdToken: busd token address
     * @param _joinStartAt: time to start joining pool
     * @param _joinEndAt: time to end joining pool
     * @param _maxPoolAllocation: Max pool allocation
     * @param _fundReceiver: address to receive busd
     */
    function setConfig(
        address _busdToken,
        uint256 _joinStartAt,
        uint256 _joinEndAt,
        uint256 _maxPoolAllocation,
        address _fundReceiver
    ) 
        external 
        onlyOwner 
    {
        require(!isInitialized, "Pool is already initilized");
        require(_busdToken != address(0), "Invalid address");
        require(
            _joinStartAt > 0 && _joinEndAt > 0, 
            "Invalid timestamp"
        );
        require(
            _maxPoolAllocation > 0,
            "Invalid number"
        );
        require(_fundReceiver != address(0), "Invalid address");

        isInitialized = true;
        busdToken = _busdToken;
        joinStartAt = _joinStartAt;
        joinEndAt = _joinEndAt;
        maxPoolAllocation = _maxPoolAllocation;
        fundReceiver = _fundReceiver;
    }


    /**
     * @notice whitelist address to pool and update number of slot if existed.
     * @dev only call by owner
     * @param _addresses: list whitelist address
     */
    function addWhitelistAddress(
        address[] memory _addresses
    ) 
        external 
        onlyOwner 
    {
        require(isInitialized, "Pool is not initialize");
        for (uint256 index = 0; index < _addresses.length; index++) {
            whitelistAddress[_addresses[index]] = whitelistAddress[_addresses[index]] + 1;
        }
    }

    /**
     * @notice remove whitelist address
     * @dev only call by owner
     */
    function removeWhitelistAddress(
        address[] memory _addresses
    ) 
        external 
        onlyOwner 
    {
        for (uint256 index = 0; index < _addresses.length; index++) {
            whitelistAddress[_addresses[index]] = 0;
        }        
    }

    /**
     * @notice Add user max allocation for joining IDO
     * @dev only call by owner
     * @param _addresses: list user addresses
     * @param _maxAllocation: their corresponding allocation
     */
    function addUserMaxAllocation(
        address[] memory _addresses,
        uint256[] memory _maxAllocation
    ) 
        external 
        onlyOwner 
    {
        require(isInitialized, "Pool is not initilize");
        for (uint256 index = 0; index < _addresses.length; index++) {
            userMaxAllocation[_addresses[index]] = _maxAllocation[index];
        }
    }

    /**
     * @notice remove whitelist address
     * @dev call by external
     * @param _amount: amount used to join IDO
     */
    function join(uint256 _amount) external {
        require(isInitialized, "Pool is not initilize");
        require(_amount > 0, "Invalid amount");
        require(
            userJoinedAmount[_msgSender()] + _amount <= userMaxAllocation[_msgSender()],
            "Exceed the amount to join IDO"
        );

        require(
            whitelistAddress[_msgSender()] > 0, 
            "You are not whitelisted"
        );

        require(
            totalJoined <= maxPoolAllocation,
            "Exceed max pool allocation for this IDO"
        );

        require(
            block.timestamp >= joinStartAt,
            "Join pool has not started yet"
        );

        require(
            block.timestamp <= joinEndAt,
            "Join pool has ended"
        );    

        // Setting 
        isJoined[_msgSender()] = true;
        totalJoined += _amount;
        joinedCount += 1;

        // Transfer token from user to fundReceiver
        IERC20(busdToken).transferFrom(_msgSender(), fundReceiver, _amount);
        
        // Amount BUSD has been joined by user
        userJoinedAmount[_msgSender()] = userJoinedAmount[_msgSender()] + _amount;

        // Joined event
        emit EventJoined(
            _msgSender(),
            _amount,
            block.timestamp
        );
    }

    /**
     * @notice change join start time
     * @dev only call by owner
     */
    function changeJoinStart(uint256 _joinStartAt) external onlyOwner {
        require(_joinStartAt > 0, "Invalid timestamp");
        joinStartAt = _joinStartAt;
    }

    /**
     * @notice change join end time
     * @dev only call by owner
     */
    function changeJoinEnd(uint256 _joinEndAt) external onlyOwner {
        require(_joinEndAt > 0, "Invalid timestamp");
        joinEndAt = _joinEndAt;
    }

    /**
     * @notice change fund receiver
     * @dev only call by owner
     */
    function changeFundReceiver(address _fundReceiver) external onlyOwner {
        require(_fundReceiver != address(0), "Invalid address");
        fundReceiver = _fundReceiver;
    }

    /**
     * @notice change pool max allocation
     * @dev only call by owner
     */
    function changeMaxPoolAllocation(uint256 _maxPoolAllocation) external onlyOwner {
        require(_maxPoolAllocation > 0, "Invalid allocation");
        maxPoolAllocation = _maxPoolAllocation;
    }

    /**
     * @notice Withdraw staked tokens without caring about rewards rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        ERC20(busdToken).transfer(address(msg.sender), _amount);
    }

}