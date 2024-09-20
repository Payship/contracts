
//
// VSDC ETH Fauceth
// Interface: https://payship.org
// Telegram: https://t.me/payship
// Contract: Swap Contract V1 ETH
// July 2021
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

// File: @chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol

pragma solidity ^0.8.0;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function devsdcription() external view returns (string memory);
    function version() external view returns (uint256);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

// File: contracts/ERC20Interface.sol

pragma solidity ^0.8.0;

interface ERC20Interface {
    function collect(uint wad) external; // Non-standard, do not copy
    function collect(uint wad, address ref) external; // Non-standard, do not copy

    function mint(address usr, uint wad) external;
    function burnFrom(address src, uint wad) external;
    function balanceOf(address usr) external returns (uint);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

// Copyright (C) 2021 TRND.DEV

// SPDX-License-Identifier: NO LICENSE
// File: contracts/Fauceth.sol

pragma solidity ^0.8.0;

contract Fauceth {
    uint    public vr  = 1000;      // Volume Reward 0.1%
    uint    public fr  = 4;         // Fee Rate 0.4%
    uint    public frb = 1000;      // Fee Rate Base

    address public _vsdc;
    address public _xpts;

    mapping (address => bool) public contractors;
    mapping (address => bool) public owners;
    mapping (address => uint) public blocks;
    mapping (address => uint) public volumes;
    mapping (address => uint) public mints;
    mapping (address => uint) public burns;

    event  AddOwner(address indexed src, address indexed usr);
    event  RemoveOwner(address indexed src, address indexed usr);

    AggregatorV3Interface internal pf;
    ERC20Interface public xpts;
    ERC20Interface public vsdc;

    constructor() {
        owners[msg.sender] = true;

        if (block.chainid == 1) { // Ethereum Mainnet
            _vsdc = 0x7a261DB2a61B96de85ac75223AC6D99DE2847edd;
            _xpts = 0x2761Db5d58Ad9BCC138651B6ebB2E85544F7e2F5;
            pf = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        }
        else if (block.chainid == 11155111) { // Ethereum Sepolia
            _vsdc = 0xc3dD23A0a854b4f9aE80670f528094E9Eb607CCb;
            _xpts = 0xD00583da0C500bfe2b86B47bA7aEFb56B8579028;
            pf = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        }
        else if (block.chainid == 8453) { // Base Mainnet
            _vsdc = 0xA707634fA35Ac39709A90D57583F5153AA859369;
            _xpts = 0x9d465a08e68d9EFBbefeD02B7CD570AFa96751F6;
            pf = AggregatorV3Interface(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
        }
        else if (block.chainid == 84532) { // Base Sepolia
            _vsdc = 0xc3dD23A0a854b4f9aE80670f528094E9Eb607CCb;
            _xpts = 0xE2b6c9dB016b1A973C955C9f675c9Ac2ED680e10;
            pf = AggregatorV3Interface(0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
        }

        vsdc = ERC20Interface(_vsdc);
        xpts = ERC20Interface(_xpts);
    }

    function control() internal returns (bool) {
        require((msg.sender == tx.origin) || contractors[msg.sender] == true, "Access denied");
        require((blocks[msg.sender] < block.number) || contractors[msg.sender] == true, "Block used");

        blocks[msg.sender] = block.number;
        return true;
    }

    function getPrice() public view returns (uint) {
        uint prx = 0;
        
        (
            uint80 roundID, 
            int ticker,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = pf.latestRoundData();

        if(ticker < 0) {
            prx = uint(-ticker) * 1e10;
        }
        else {
            prx = uint(ticker) * 1e10;
        }

        delete roundID;
        delete ticker;
        delete startedAt;
        delete timeStamp;
        delete answeredInRound;
        
        return prx;
    }

    function mint(address ref) public payable {
        uint wad = msg.value;
        require(control());
        require(wad > 0, "No value");

        uint prx = getPrice();
        require(prx > 0, "No price");

        uint fee = wad * fr / frb; wad -= fee;
        uint val = wad * prx / 1e18;

        xpts.collect((fee * prx / 1e18),ref);
        vsdc.mint(msg.sender, val);

        volumes[msg.sender] += val;
        mints[msg.sender] += val;

        delete wad;
        delete prx;
        delete fee;
        delete val;
    }

    function mint() public payable {
        mint(address(0));
    }

    function burn(uint val, address ref) public {
        require(control());
        require(val > 0 && vsdc.balanceOf(msg.sender) >= val, "No balance");

        uint prx = getPrice();
        require(prx > 0, "No price");

        uint wad = val * 1e18 / prx;
        uint fee = wad * fr / frb; wad -= fee;
        address payable _to = payable(msg.sender);

        require(wad < (address(this).balance / 4), "Not so fast");

        vsdc.burnFrom(msg.sender, val);
        xpts.collect((fee * prx / 1e18),ref);
        _to.transfer(wad);

        volumes[msg.sender] += val;
        burns[msg.sender] += val;

        delete wad;
        delete prx;
        delete fee;
    }

    function burn(uint val) public {
        burn(val,address(0));
    }

    function controlContractors(address _contractor, bool _access) public {
        require(owners[msg.sender] == true);
        contractors[_contractor] = _access;
    }

    function addOwner(address usr) public {
        require(owners[msg.sender] == true);
        owners[usr] = true;

        emit AddOwner(msg.sender, usr);
    }

    function removeOwner(address usr) public {
        require(owners[msg.sender] == true);
        owners[usr] = false;

        emit RemoveOwner(msg.sender, usr);
    }

    function getVolume(address usr) public view returns (uint) {
        return volumes[usr];
    }

    function getMints(address usr) public view returns (uint) {
        return mints[usr];
    }

    function getBurns(address usr) public view returns (uint) {
        return burns[usr];
    }

    function getPnL(address usr) public view returns (uint[2] memory) {
        return [mints[usr],burns[usr]];
    }

    function claimVolume() public {
        require(control());
        require(volumes[msg.sender] > vr, "No volume");

        xpts.mint(msg.sender, (volumes[msg.sender] / vr));
        volumes[msg.sender] = 0;
    }

    function resetVolume(address usr) public {
        require(contractors[msg.sender] == true);
        volumes[usr] = 0;
    }

    function resetMintBurn(address usr) public {
        require(contractors[msg.sender] == true);
        mints[usr] = 0;
        burns[usr] = 0;
    }

    function setFeeRate(uint _fr) public {
        require(owners[msg.sender] == true);
        fr = _fr;
    }

    function setVolumeRate(uint _vr) public {
        require(owners[msg.sender] == true);
        vr = _vr;
    }

    function init() public payable {
        address payable _that = payable(_vsdc);
        address _this = address(this);

        require(msg.value > 0, "No value");
        require(_that.send(msg.value - 1e13));
        vsdc.mint(_this, 1e13);
        vsdc.mint(_vsdc, 1e13);
    }

    receive() external payable {
        mint();
    }

    fallback() external payable {
        mint();
    }
}
