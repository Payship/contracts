
//
// Swapsynt
// Interface: https://payship.org
// Telegram: https://t.me/payship
// Contract: Synthetic Swap Contract V1
// April 2022
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
    function description() external view returns (string memory);
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

// Copyright (C) 2022 TRND.DEV

// SPDX-License-Identifier: NO LICENSE
// File: contracts/Swapsynt01.sol

pragma solidity ^0.8.0;

contract Swapsynt {
    ERC20Interface public vsdc;
    ERC20Interface public xpts;

    struct Synt {
        uint    id;

        uint    price;
        uint    balance;

        bytes32 symbol;
        bytes   ticker;
        address oracle;
    }

    uint    public fr                = 4;         // Fee Rate 0.4%
    uint    public frb               = 1000;      // Fee Rate Base

    uint    public cr                = 40;        // Credit Rate 4%
    uint    public crb               = 1000;      // Credit Rate Base

    uint    public vr                = 1000;      // Volume Reward 0.1%

    uint    public _sid              = 0;
    uint    public _credit_total     = 0;
    uint    public _credit_size      = 0;
    uint    public _credit_max       = 0;

    bytes32   public constant sVSDC  = keccak256("VSDC");
    address[] public traderList;

    mapping (address => bool) public contractors;
    mapping (address => bool) public owners;

    mapping (address => bool) public credit_status;
    mapping (address => uint) public credit_lines;

    mapping (address => uint) public blocks;
    mapping (address => uint) public volumes;
    mapping (address => uint) public traders;
    mapping (address => uint) public buys;
    mapping (address => uint) public sells;

    mapping (bytes32 => Synt) public synts;
    mapping (uint => bytes32) public syntList;
    mapping (address => mapping (bytes32 => uint)) public balances;

    event  OpenCredit();
    event  CloseCredit();
    event  Deposit(uint val);
    event  Withdraw(uint val);

    event  Buy(bytes32 symbol, uint val);
    event  Sell(bytes32 symbol, uint val);
    event  Swap(bytes32 from, bytes32 to, uint val);
    event  AddOwner(address indexed src, address indexed usr);
    event  RemoveOwner(address indexed src, address indexed usr);

    constructor() {
        owners[msg.sender] = true;
        addAsset("VSDC", address(0));

        if (block.chainid == 1) { // Ethereum Mainnet
            vsdc = ERC20Interface(0x7a261DB2a61B96de85ac75223AC6D99DE2847edd);
            xpts = ERC20Interface(0x2761Db5d58Ad9BCC138651B6ebB2E85544F7e2F5);

            addAsset("ETH", 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
            addAsset("BTC", 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);

            addAsset("SOL", 0x4ffC43a60e009B551865A93d232E33Fce9f01507);
            addAsset("BNB", 0x14e613AC84a31f709eadbdF89C6CC390fDc9540A);
            addAsset("POL", 0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676);
            addAsset("ARB", 0x31697852a68433DbCc2Ff612c516d69E3D9bd08F);
            addAsset("AVAX", 0xFF3EEb22B5E3dE6e705b44749C2559d704923FD7);

            addAsset("AAVE", 0x547a514d5e3769680Ce22B2361c10Ea13619e8a9);
            addAsset("APE", 0xD10aBbC76679a20055E167BB80A24ac851b37056);
            addAsset("BAL", 0xdF2917806E30300537aEB49A7663062F4d1F2b5F);
            addAsset("COMP", 0xdbd020CAeF83eFd542f4De03e3cF0C28A4428bd5);
            addAsset("CRV", 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f);
            addAsset("ENS", 0x5C00128d4d1c2F4f652C267d7bcdD7aC99C16E16);
            addAsset("GRT", 0x86cF33a451dE9dc61a2862FD94FF4ad4Bd65A5d2);
            addAsset("IMX", 0xBAEbEFc1D023c0feCcc047Bff42E75F15Ff213E6);
            addAsset("LINK", 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c);
            addAsset("MKR", 0xec1D1B3b0443256cc3860e24a46F108e699484Aa);
            addAsset("RDNT", 0x393CC05baD439c9B36489384F11487d9C8410471);
            addAsset("SNX", 0xDC3EA94CD0AC27d9A86C180091e7f78C683d3699);
            addAsset("STG", 0x7A9f34a0Aa917D438e9b6E630067062B7F8f6f3d);
            addAsset("SUSHI", 0xCc70F09A6CC17553b2E31954cD36E4A2d89501f7);
            addAsset("TAO", 0x1c88503c9A52aE6aaE1f9bb99b3b7e9b8Ab35459);
            addAsset("UNI", 0x553303d460EE0afB37EdFf9bE42922D8FF63220e);
            addAsset("YFI", 0xA027702dbb89fbd58938e4324ac03B58d812b0E1);
            addAsset("ZRX", 0x2885d15b8Af22648b98B122b22FDF4D2a56c6023);

            addAsset("AUD", 0x77F9710E7d0A19669A13c055F62cd80d313dF022);
            addAsset("CAD", 0xa34317DB73e77d453b1B8d04550c44D10e981C8e);
            addAsset("CHF", 0x449d117117838fFA61263B61dA6301AA2a88B13A);
            addAsset("CNY", 0xeF8A4aF35cd47424672E3C590aBD37FBB7A7759a);
            addAsset("EUR", 0xb49f677943BC038e9857d61E7d053CaA2C1734C1);
            addAsset("GBP", 0x5c0Ab2d9b5a7ed9f470386e82BB36A3613cDd4b5);
            addAsset("JPY", 0xBcE206caE7f0ec07b545EddE332A47C2F75bbeb3);
            addAsset("KRW", 0x01435677FB11763550905594A16B645847C1d0F3);
            addAsset("NZD", 0x3977CFc9e4f29C184D4675f4EB8e0013236e5f3e);
            addAsset("SGD", 0xe25277fF4bbF9081C75Ab0EB13B4A13a721f3E13);
            addAsset("TRY", 0xB09fC5fD3f11Cf9eb5E1C5Dba43114e3C9f477b5);

            addAsset("CSPX", 0xF4E1B57FB228879D057ac5AE33973e8C53e4A0e0);
            addAsset("XAU", 0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6);
            addAsset("XAG", 0x379589227b15F1a12195D3f2d90bBc9F31f95235);
        }
        else if (block.chainid == 11155111) { // Ethereum Sepolia
            vsdc = ERC20Interface(0xc3dD23A0a854b4f9aE80670f528094E9Eb607CCb);
            xpts = ERC20Interface(0xD00583da0C500bfe2b86B47bA7aEFb56B8579028);

            addAsset("ETH", 0x694AA1769357215DE4FAC081bf1f309aDC325306);
            addAsset("BTC", 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);

            addAsset("LINK", 0xc59E3633BAAC79493d908e63626716e204A45EdF);
            addAsset("FORTH", 0x070bF128E88A4520b3EfA65AB1e4Eb6F0F9E6632);
            addAsset("SNX", 0xc0F82A46033b8BdBA4Bb0B0e28Bc2006F64355bC);

            addAsset("EUR", 0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910);
            addAsset("GBP", 0x91FAB41F5f3bE955963a986366edAcff1aaeaa83);
            addAsset("JPY", 0x8A6af2B75F23831ADc973ce6288e5329F63D86c6);
        }
        else if (block.chainid == 8453) { // Base Mainnet
            vsdc = ERC20Interface(0xA707634fA35Ac39709A90D57583F5153AA859369);
            xpts = ERC20Interface(0x9d465a08e68d9EFBbefeD02B7CD570AFa96751F6);

            addAsset("ETH", 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
            addAsset("BTC", 0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F);

            addAsset("SOL", 0x975043adBb80fc32276CbF9Bbcfd4A601a12462D);
            addAsset("BNB", 0x4b7836916781CAAfbb7Bd1E5FDd20ED544B453b1);
            addAsset("DOGE", 0x8422f3d3CAFf15Ca682939310d6A5e619AE08e57);
            addAsset("POL", 0x12129aAC52D6B0f0125677D4E1435633E61fD25f);
            addAsset("AVAX", 0xE70f2D34Fd04046aaEC26a198A35dD8F2dF5cd92);
            addAsset("APT", 0x88a98431C25329AA422B21D147c1518b34dD36F4);
            addAsset("OP", 0x3E3A6bD129A63564FE7abde85FA67c3950569060);
            
            addAsset("AXL", 0x676C4C6C31D97A5581D3204C04A8125B350E2F9D);
            addAsset("COMP", 0x9DDa783DE64A9d1A60c49ca761EbE528C35BA428);
            addAsset("LINK", 0x17CAb8FE31E32f08326e5E27412894e49B0f9D65);
            addAsset("PEPE", 0xB48ac6409C0c3718b956089b0fFE295A10ACDdad);
            addAsset("SNX", 0xe3971Ed6F1A5903321479Ef3148B5950c0612075);
            addAsset("STG", 0x63Af8341b62E683B87bB540896bF283D96B4D385);
            addAsset("SHIB", 0xC8D5D660bb585b68fa0263EeD7B4224a5FC99669);
            addAsset("RDNT", 0xEf2E24ba6def99B5e0b71F6CDeaF294b02163094);
            addAsset("RSR", 0xAa98aE504658766Dfe11F31c5D95a0bdcABDe0b1);
            addAsset("YFI", 0xD40e758b5eC80820B68DFC302fc5Ce1239083548);
            addAsset("ZRO", 0xdc31a4CCfCA039BeC6222e20BE7770E12581bfEB);

            addAsset("EUR", 0xc91D87E81faB8f93699ECf7Ee9B44D11e1D53F0F);
            addAsset("BRL", 0x0b0E64c05083FdF9ED7C5D3d8262c4216eFc9394);
        }
        else if (block.chainid == 84532) { // Base Sepolia
            vsdc = ERC20Interface(0xc3dD23A0a854b4f9aE80670f528094E9Eb607CCb);
            xpts = ERC20Interface(0xE2b6c9dB016b1A973C955C9f675c9Ac2ED680e10);
            
            addAsset("ETH", 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1);
            addAsset("BTC", 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298);

            addAsset("LINK", 0xb113F5A928BCfF189C998ab20d753a47F9dE5A61);
        }
    }

    function getPrice(address oracle) public view returns (uint) {
        AggregatorV3Interface feed = AggregatorV3Interface(oracle);
        uint prx = 0;
        
        (
            uint80 roundID, 
            int ticker,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = feed.latestRoundData();

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

    function getFolio() public view returns (Synt[] memory) {
        bytes32 symbol;
        Synt[] memory folio = new Synt[](_sid);

        for (uint i = 0; i < _sid; i++) {
            symbol = syntList[i];

            folio[i] = synts[symbol];
            folio[i].balance = balances[msg.sender][symbol];
        }

        return folio;
    }

    function control() internal returns (bool) {
        require((msg.sender == tx.origin) || contractors[msg.sender] == true, "Access denied");
        require((blocks[msg.sender] < block.number) || contractors[msg.sender] == true, "Block used");

        blocks[msg.sender] = block.number;
        return true;
    }

    function editCreditMax(uint _wad) public {
        require(owners[msg.sender] == true);
        _credit_max = _wad;
    }

    function editCreditSize(uint _wad) public {
        require(owners[msg.sender] == true);
        _credit_size = _wad;
    }

    function addAsset(bytes memory _ticker, address _oracle) public {
        require(owners[msg.sender] == true);
        bytes32 _symbol = keccak256(_ticker);

        synts[_symbol] = Synt(_sid, 0, 0, _symbol, _ticker, _oracle);
        syntList[_sid] = _symbol;

        _sid += 1;
    }

    function editAsset(uint _id, address _oracle) public {
        require(owners[msg.sender] == true);
        bytes32 _symbol = syntList[_id];

        synts[_symbol].oracle = _oracle;
    }

    function openCreditLine() public {
        require(control());
        require(_credit_size > 0, "No credit");
        require(_credit_total + _credit_size <= _credit_max, "Credit limit");
        require(credit_status[msg.sender] == false, "Credit used");

        credit_status[msg.sender] = true;
        credit_lines[msg.sender] = _credit_size;
        balances[msg.sender][sVSDC] += _credit_size;

        _credit_total += _credit_size;
        emit OpenCredit();
    }

    function closeCreditLine(address ref) public {
        require(control());

        uint itr = credit_lines[msg.sender] * cr / crb;
        uint tot = credit_lines[msg.sender] + itr;
        require(balances[msg.sender][sVSDC] >= tot, "No sVSDC");

        balances[msg.sender][sVSDC] -= tot;
        xpts.collect(itr,ref);

        _credit_total -= credit_lines[msg.sender];
        
        credit_lines[msg.sender] = 0;
        emit CloseCredit();
    }

    function closeCreditLine() public {
        closeCreditLine(address(0));
    }

    function buyAsset(bytes32 _symbol, uint _wad, bool _bal, address _ref) public {
        require(control());
        require(_wad > 0, "No size");

        address oracle = synts[_symbol].oracle;
        require(oracle != address(0), "No oracle");

        uint prx = getPrice(oracle);
        require(prx > 0, "No price");

        uint fee = _wad * fr / frb;
        uint size = _wad - fee;
        uint val = size * 1e18 / prx;

        if (_bal == true) {
            require(balances[msg.sender][sVSDC] >= _wad, "No sVSDC");

            balances[msg.sender][sVSDC] -= _wad;
            xpts.collect(fee,_ref);
        }
        else {
            require(vsdc.balanceOf(msg.sender) >= _wad, "No VSDC");

            vsdc.burnFrom(msg.sender, _wad);
            xpts.collect(fee,_ref);
        }

        balances[msg.sender][_symbol] += val;

        volumes[msg.sender] += size;
        buys[msg.sender] += size;

        listTrader(msg.sender);
        emit Buy(_symbol, val);
    }

    function buyAsset(bytes32 _symbol, uint _wad, bool _bal) public {
        buyAsset(_symbol,_wad,_bal,address(0));
    }

    function sellAsset(bytes32 _symbol, uint _size, bool _bal, address _ref) public {
        require(control());
        require(_size > 0, "No size");
        require(balances[msg.sender][_symbol] >= _size, "No asset");
        if (_bal == false) require(credit_lines[msg.sender] <= 0, "Credit open");

        address oracle = synts[_symbol].oracle;
        require(oracle != address(0), "No oracle");

        uint prx = getPrice(oracle);
        require(prx > 0, "No price");

        uint val = prx * _size / 1e18;
        uint fee = val * fr / frb; val -= fee;

        balances[msg.sender][_symbol] -= _size;

        if (_bal == true) {
            balances[msg.sender][sVSDC] += val;
            xpts.collect(fee,_ref);
        }
        else {
            vsdc.mint(msg.sender, val);
            xpts.collect(fee,_ref);
        }

        volumes[msg.sender] += val;
        sells[msg.sender] += val;

        listTrader(msg.sender);
        emit Sell(_symbol, _size);
    }

    function sellAsset(bytes32 _symbol, uint _size, bool _bal) public {
        sellAsset(_symbol,_size,_bal,address(0));
    }

    function swapAsset(bytes32 _from, bytes32 _to, uint _wad, address _ref) public {
        require(control());
        require(_wad > 0, "No size");
        require(synts[_from].oracle != address(0), "No oracle");
        require(synts[_to].oracle != address(0), "No oracle");
        require(balances[msg.sender][_from] >= _wad, "No asset");

        address oracle_from = synts[_from].oracle;
        address oracle_to = synts[_to].oracle;
        uint prx_from = 1e18;
        uint prx_to = 1e18;

        if (oracle_from != address(0)) {
            prx_from = getPrice(oracle_from);
        }
        if (oracle_to != address(0)) {
            prx_to = getPrice(oracle_to);
        }

        uint val = prx_from * _wad;
        uint fee = val * fr / frb;
             val -= fee; fee /= 1e18;
        uint to_wad = val / prx_to;

        balances[msg.sender][_from] -= _wad;
        balances[msg.sender][_to] += to_wad;
        xpts.collect(fee,_ref);

        volumes[msg.sender] += (val / 1e18);

        listTrader(msg.sender);
        emit Swap(_from, _to, _wad);
    }

    function swapAsset(bytes32 _from, bytes32 _to, uint _wad) public {
        swapAsset(_from,_to,_wad,address(0));
    }

    function deposit(uint _wad) public {
        require(control());
        require(_wad > 0, "No size");
        require(vsdc.balanceOf(msg.sender) >= _wad, "No VSDC");

        vsdc.burnFrom(msg.sender, _wad);
        balances[msg.sender][sVSDC] += _wad;

        emit Deposit(_wad);
    }

    function withdraw(uint _wad) public {
        require(control());
        require(_wad > 0, "No size");
        require(balances[msg.sender][sVSDC] >= _wad, "No sVSDC");
        require(credit_lines[msg.sender] <= 0, "Credit open");

        balances[msg.sender][sVSDC] -= _wad;
        vsdc.mint(msg.sender, _wad);

        emit Withdraw(_wad);
    }

    function controlContractors(address _contractor, bool _access) public {
        require(owners[msg.sender] == true);
        contractors[_contractor] = _access;
    }

    function addOwner(address _usr) public {
        require(owners[msg.sender] == true);
        owners[_usr] = true;

        emit AddOwner(msg.sender, _usr);
    }

    function removeOwner(address _usr) public {
        require(owners[msg.sender] == true);
        owners[_usr] = false;

        emit RemoveOwner(msg.sender, _usr);
    }

    function getVolume(address usr) public view returns (uint) {
        return volumes[usr];
    }

    function getBuys(address usr) public view returns (uint) {
        return buys[usr];
    }

    function getSells(address usr) public view returns (uint) {
        return sells[usr];
    }

    function getPnL(address usr) public view returns (uint[2] memory) {
        return [buys[usr],sells[usr]];
    }

    function countTraders() public view returns (uint) {
        return traderList.length;
    }

    function listTrader(address usr) private {
        if (traders[usr] == 0) {
            traderList.push(usr);
        }
        traders[usr] += 1;
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

    function resetBuySell(address usr) public {
        require(contractors[msg.sender] == true);
        buys[usr] = 0;
        sells[usr] = 0;
    }

    function setFeeRate(uint _fr) public {
        require(owners[msg.sender] == true);
        fr = _fr;
    }

    function setCreditRate(uint _cr) public {
        require(owners[msg.sender] == true);
        cr = _cr;
    }

    function setVolumeRate(uint _vr) public {
        require(owners[msg.sender] == true);
        vr = _vr;
    }
}
