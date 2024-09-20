//
// "Here's to the crazy ones..." the degens, the chads, the farmers.
//
// Farmlend
// Interface: https://payship.org
// Telegram: https://t.me/payship
// Contract: Farm & Lend Contract V1
// May 2024
//

// /////////////////////////////// //
//                                 //
//  [][][]  []][]  [][]]   [][]]   //
//    []    []     []  []  []  []  //
//    []    []     []  []  [][]]   //
//                                 //
//  DYOR NFA YOLO        TRND.DEV  //
//                                 //
// /////////////////////////////// //

// Copyright (C) 2024 TRND.DEV

// SPDX-License-Identifier: NO LICENSE
// File: contracts/ERC20Interface.sol

pragma solidity ^0.8.0;

interface ERC20Interface {
    function collect(uint wad) external; // Non-standard, do not copy
    function collect(uint wad, address ref) external; // Non-standard, do not copy

    function mint(address usr, uint wad) external;
    function burnFrom(address src, uint wad) external;
    function balanceOf(address usr) external returns (uint);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

contract Farmlend {

    uint  public cr            = 40;        // Credit Rate 4%
    uint  public crb           = 1000;      // Credit Rate Base

    uint  public frb           = 1e18;      // Farm Rate Base

    uint  public gm            = 1;         // Global Multiplier
    uint  public bir           = 2628000;   // Blocks in 1 Year

    // Info of each lender.
    struct LenderInfo {
        uint value;            // How much LP tokens are worth as collateral.
        uint borrowedDebt;     // Lend debt. Size of the credit.
        uint lastBorrowBlock;  // Last block number that borrowing occurs.
    }

    // Info of each user.
    struct UserInfo {
        uint amount;           // How many LP tokens the user has provided.
        uint lastRewardBlock;  // Last block number that rewarding occurs.
    }

    // Info of each pool.
    struct PoolInfo {
        ERC20Interface lpToken;   // Address of LP token contract.
        uint ptsPerShare;      // Fixed share value, for rewards.
        uint valPerShare;      // Fixed share value, for lending.
    }

    // The XPTS!
    ERC20Interface public xpts;
    address public _xpts;
    // The VSDC TOKEN!
    ERC20Interface public vsdc;
    address public _vsdc;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes any token.
    mapping (address => LenderInfo) public lenderInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint => mapping (address => UserInfo)) public userInfo;

    mapping (address => bool) public contractors;
    mapping (address => bool) public owners;
    mapping (address => uint) public blocks;

    event Deposit(address indexed user, uint indexed pid, uint amount);
    event Withdraw(address indexed user, uint indexed pid, uint amount);
    event EmergencyWithdraw(address indexed user, uint indexed pid, uint amount);

    constructor() {
        owners[msg.sender] = true;

        if (block.chainid == 1) { // Ethereum Mainnet
            bir = 2628000;
            _vsdc = 0x7a261DB2a61B96de85ac75223AC6D99DE2847edd;
            _xpts = 0x2761Db5d58Ad9BCC138651B6ebB2E85544F7e2F5;
        }
        else if (block.chainid == 11155111) { // Ethereum Sepolia
            bir = 2628000;
            _vsdc = 0xc3dD23A0a854b4f9aE80670f528094E9Eb607CCb;
            _xpts = 0xD00583da0C500bfe2b86B47bA7aEFb56B8579028;
        }
        else if (block.chainid == 8453) { // Base Mainnet
            bir = 15768000;
            _vsdc = 0xA707634fA35Ac39709A90D57583F5153AA859369;
            _xpts = 0x9d465a08e68d9EFBbefeD02B7CD570AFa96751F6;
        }
        else if (block.chainid == 84532) { // Base Sepolia
            bir = 15768000;
            _vsdc = 0xc3dD23A0a854b4f9aE80670f528094E9Eb607CCb;
            _xpts = 0xE2b6c9dB016b1A973C955C9f675c9Ac2ED680e10;
        }

        vsdc = ERC20Interface(_vsdc);
        xpts = ERC20Interface(_xpts);

        addPool(_vsdc,(50*1e16),0);
    }

    function control() internal returns (bool) {
        require((msg.sender == tx.origin) || contractors[msg.sender] == true, "Access denied");
        require((blocks[msg.sender] < block.number) || contractors[msg.sender] == true, "Block used");

        blocks[msg.sender] = block.number;
        return true;
    }

    function controlContractors(address _contractor, bool _access) public {
        require(owners[msg.sender] == true);
        contractors[_contractor] = _access;
    }

    function poolLength() public view returns (uint) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function addPool(address _lpToken, uint _ptsPerShare, uint _valPerShare) public {
        require(owners[msg.sender] == true);

        poolInfo.push(PoolInfo({
            lpToken: ERC20Interface(_lpToken),
            ptsPerShare: _ptsPerShare,
            valPerShare: _valPerShare
        }));
    }

    // Update the global interest rate. Can only be called by the owner.
    function setCreditRate(uint _cr) public {
        require(owners[msg.sender] == true);
        cr = _cr;
    }

    // Update the farm rate. Can only be called by the owner.
    function setFarmRate(uint _frb) public {
        require(owners[msg.sender] == true);
        frb = _frb;
    }

    // Update the global multiplier. Can only be called by the owner.
    function setMultiplier(uint _multiplier) public {
        require(owners[msg.sender] == true);
        gm = _multiplier;
    }

    // Update the given pool's xpts allocation point. Can only be called by the owner.
    function setPool(uint _pid, uint _ptsPerShare, uint _valPerShare) public {
        require(owners[msg.sender] == true);

        poolInfo[_pid].ptsPerShare = _ptsPerShare;
        poolInfo[_pid].valPerShare = _valPerShare;
    }

    function pendingPoints(uint _pid, address _user) public view returns (uint) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint pending = 0;

        if (block.number > user.lastRewardBlock) {
            uint bs = block.number - user.lastRewardBlock;
            pending = (user.amount * pool.ptsPerShare * bs * gm) / (bir * frb);
        }

        return pending;
    }

    // Deposit LP tokens to CaptainCook for xpts allocation.
    function deposit(uint _pid, uint _amount) public {
        require(control());

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        LenderInfo storage lender = lenderInfo[msg.sender];

        if (user.amount > 0 && user.lastRewardBlock > 0) {
            uint pending = pendingPoints(_pid,msg.sender);

            if (pending > 0) {
                xpts.mint(msg.sender, pending);
            }
        }

        user.lastRewardBlock = block.number;

        if (_amount > 0) {
            pool.lpToken.transferFrom(msg.sender, address(this), _amount);

            user.amount += _amount;
            lender.value += (_amount * pool.valPerShare / frb);
        }

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from CaptainCook.
    function withdraw(uint _pid, uint _amount) public {
        require(control());

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        LenderInfo storage lender = lenderInfo[msg.sender];

        require(_amount <= user.amount, "withdraw: not good");
        require((2 * lender.borrowedDebt) <= (lender.value - (_amount * pool.valPerShare / frb)), "withdraw: not good, reduce credit");

        if (user.amount > 0 && user.lastRewardBlock > 0) {
            uint pending = pendingPoints(_pid,msg.sender);

            if (pending > 0) {
                xpts.mint(msg.sender, pending);
            }
        }

        user.amount -= _amount;
        lender.value -= (_amount * pool.valPerShare / frb);

        user.lastRewardBlock = block.number;
        pool.lpToken.transfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function borrow(uint _amount, address _ref) public {
        require(control());
        require(_amount > (2 * crb));

        LenderInfo storage lender = lenderInfo[msg.sender];
        uint pendingInterest = calculateInterest(msg.sender);
        uint creditFee = (_amount * cr) / (2 * crb);

        require((lender.borrowedDebt + _amount + pendingInterest) <= lender.value, "borrow: not good, add collateral");

        lender.borrowedDebt = lender.borrowedDebt + _amount + pendingInterest;
        lender.lastBorrowBlock = block.number;
        _amount -= creditFee;

        xpts.collect(creditFee,_ref);
        vsdc.mint(msg.sender, _amount);
    }

    function borrow(uint _amount) public {
        borrow(_amount,address(0));
    }

    function repay(uint _amount, address _ref) public {
        require(control());
        require(_amount > 0);

        LenderInfo storage lender = lenderInfo[msg.sender];
        uint pendingInterest = calculateInterest(msg.sender);
        require(_amount <= (lender.borrowedDebt + pendingInterest), "repay: not good, amount too big");

        vsdc.burnFrom(msg.sender, _amount);
        xpts.collect(pendingInterest,_ref);

        lender.borrowedDebt = lender.borrowedDebt + pendingInterest - _amount;
        lender.lastBorrowBlock = block.number;
    }

    function repay(uint _amount) public {
        repay(_amount,address(0));
    }

    // Calculate interest
    function calculateInterest(address _user) public view returns (uint) {
        LenderInfo storage lender = lenderInfo[_user];
        uint blocksElapsed = block.number - lender.lastBorrowBlock;
        uint lenderDebt = lender.borrowedDebt;
        return ((lenderDebt * cr * blocksElapsed) / (crb * bir));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint _pid) public {
        require(control());

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        LenderInfo storage lender = lenderInfo[msg.sender];

        require((2 * lender.borrowedDebt) <= (lender.value - (user.amount * pool.valPerShare / frb)), "withdraw: not good, reduce credit");

        user.lastRewardBlock = block.number;
        pool.lpToken.transfer(msg.sender, user.amount);
        user.amount = 0;
        
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }
}
