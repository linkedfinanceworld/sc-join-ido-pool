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

    // timestamp when IDO Pool starts
    uint256 public joinStartAt;

    // timestamp when IDO Pool ends
    uint256 public joinEndAt;

    // Maximum allocation amount for pool
    uint256 public maxPoolAllocation;

    // Is the pool initialized yet
    bool public isInitialized; 

    // Mapping isjoined for an address
    mapping(address => bool) public isJoined;

    // user address => pool name => number of slot.
    mapping(address => bool) public whitelistAddress;

    // user max allocation
    mapping(address => uint256) public userMaxAllocation;

    // how much BUSD that each user has transfered to pool
    mapping(address => uint256) public userJoinedAmount;

    event Join(address indexed sender, uint256 amount, uint256 date);

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
        require(!isInitialized, "Pool is already initialized");
        require(_busdToken != address(0), "Invalid BUSD address");
        require(
            _joinEndAt > _joinStartAt && _joinStartAt > 0, 
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
     * @param _addresses: list of addresses that will be whitelisted
     */
    function addWhitelistAddress(address[] memory _addresses) external onlyOwner 
    {
        require(isInitialized, "Pool is not initialized");
        for (uint256 index = 0; index < _addresses.length; index++) {
            whitelistAddress[_addresses[index]] = true;
        }
    }

    /**
     * @notice remove whitelist addresses
     * @dev only call by owner
     * @param _addresses: list of addresses that will be not whitelisted anymore
     */
    function removeWhitelistAddress( address[] memory _addresses) external onlyOwner 
    {
        for (uint256 index = 0; index < _addresses.length; index++) {
            whitelistAddress[_addresses[index]] = false;
        }        
    }

    /**
     * @notice Add user max allocation for joining IDO
     * @dev only call by owner
     * @param _addresses: list of user addresses
     * @param _maxAllocation: their corresponding max allocation values
     */
    function addUserMaxAllocation(
        address[] memory _addresses,
        uint256[] memory _maxAllocation
    ) 
        external 
        onlyOwner 
    {
        require(_addresses.length == _maxAllocation.length, 
                "Length of addresses and allocation values are different");
        require(isInitialized, "Pool is not initialized");
        for (uint256 index = 0; index < _addresses.length; index++) {
            userMaxAllocation[_addresses[index]] = _maxAllocation[index];
        }
    }

    /**
     * @notice user joins IDO Pool
     * @dev call by external
     * @param _amount: amount that user spends to join IDO
     */
    function join(uint256 _amount) external {
        require(isInitialized, "Pool is not initialized");
        require(_amount > 0, "Invalid amount");
        require(
            userJoinedAmount[_msgSender()] + _amount <= userMaxAllocation[_msgSender()],
            "Exceed the amount to join IDO"
        );

        require(
            whitelistAddress[_msgSender()] == true, 
            "You are not whitelisted"
        );

        require(
            totalJoined <= maxPoolAllocation,
            "Exceed max pool allocation for this IDO"
        );

        require(
            block.timestamp >= joinStartAt,
            "The IDO pool has not opened yet"
        );

        require(
            block.timestamp <= joinEndAt,
            "The IDO pool has closed"
        );    

        if ( !isJoined[_msgSender()] ) {
            isJoined[_msgSender()] = true;
        }
        
        totalJoined += _amount;

        // Transfer token from user to fundReceiver
        IERC20(busdToken).transferFrom(_msgSender(), fundReceiver, _amount);
        
        // Amount BUSD has been joined by user
        userJoinedAmount[_msgSender()] = userJoinedAmount[_msgSender()] + _amount;

        // Joined event
        emit Join(_msgSender(), _amount, block.timestamp);
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
        require(_joinEndAt > joinStartAt, "Invalid timestamp, end time must be after start time");
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
     * @notice check if user can join or not
     * @dev for FE
     */
    function canJoin(address _usr) public view returns (bool) {
        return (whitelistAddress[_usr] && userJoinedAmount[_usr] < userMaxAllocation[_usr]);
    }
    /**
     * @notice Withdraw staked tokens without caring about rewards rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        ERC20(busdToken).transfer(address(msg.sender), _amount);
    }

}