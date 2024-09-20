
//
// XPSHP
// Interface: https://payship.org
// Telegram: https://t.me/payship
// Contract: Payship Experience Points Contract
// Jun 2024
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

// File: contracts/ERC20Interface.sol

pragma solidity ^0.8.0;

interface ERC20Interface {
    function mint(address usr, uint wad) external;
    function burnFrom(address src, uint wad) external;
    function balanceOf(address usr) external returns (uint);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
}

// Copyright (C) 2024 TRND.DEV

// SPDX-License-Identifier: NO LICENSE
// File: contracts/XPSHP.sol

pragma solidity ^0.8.0;

contract XPSHP {
    bool    public INIT                = false;
    bool    public LOCKED              = false;
    uint    public TIMELOCK;        // = 0;
    uint    public supply;          // = 0;
    uint    public staked;          // = 0;
    uint    public fees;            // = 0;
    uint    public bir                 = 2628000;   // Blocks in 1 Year
    uint    public constant decimals   = 18;
    uint    public constant MAX_INT    = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    ERC20Interface public   vsdc;
    address public         _vsdc;
    address public          chest;
    string  public constant name       = "Payship.org XP";
    string  public constant symbol     = "XPSHP";

    event  Lock(address indexed src);
    event  Grace(address indexed src);
    event  Unlock(address indexed src);

    event  Stake(address indexed src);
    event  Unstake(address indexed src);

    event  AddOwner(address indexed src, address indexed usr);
    event  RemoveOwner(address indexed src, address indexed usr);
    event  AddMinter(address indexed src, address indexed usr);
    event  RemoveMinter(address indexed src, address indexed usr);
    event  UpdateChest(address indexed src, address indexed usr);

    event  Approval(address indexed src, address indexed usr, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);

    mapping (address => bool)                       public  owners;
    mapping (address => uint)                       public  blocks;
    mapping (address => bool)                       public  minters;
    mapping (address => uint)                       public  stakers;
    mapping (address => uint)                       public  rewards;
    mapping (address => uint)                       public  bonuses;

    mapping (address => uint)                       public  balance;
    mapping (address => mapping (address => uint))  public  allowance;

    constructor() {
        chest = msg.sender;
        owners[msg.sender] = true;

        if (block.chainid == 1) { // Ethereum Mainnet
            bir = 2628000;
            _vsdc = 0x7a261DB2a61B96de85ac75223AC6D99DE2847edd;
        }
        else if (block.chainid == 11155111) { // Ethereum Sepolia
            bir = 2628000;
            _vsdc = 0xc3dD23A0a854b4f9aE80670f528094E9Eb607CCb;
        }
        else if (block.chainid == 8453) { // Base Mainnet
            bir = 15768000;
            _vsdc = 0xA707634fA35Ac39709A90D57583F5153AA859369;
        }
        else if (block.chainid == 84532) { // Base Sepolia
            bir = 15768000;
            _vsdc = 0xc3dD23A0a854b4f9aE80670f528094E9Eb607CCb;
        }

        vsdc = ERC20Interface(_vsdc);
    }

    function control() internal returns (bool) {
        require((msg.sender == tx.origin) || minters[msg.sender] == true, "Access denied");
        require((blocks[msg.sender] < block.number) || minters[msg.sender] == true, "Block used");

        blocks[msg.sender] = block.number;
        return true;
    }

    function airdrop(address usr, uint wad) private {
        supply += wad;
        balance[usr] += wad;
        
        emit Transfer(address(0), usr, wad);
    }

    function mint(address usr, uint wad) public {
        require(minters[msg.sender] == true);

        supply += wad;
        balance[usr] += wad;

        if (stakers[usr] > 0) {
            staked += wad;
        }
        
        emit Transfer(address(0), usr, wad);
    }

    function stake() public {
        require(control());
        require(stakers[msg.sender] == 0, "Staking already active.");
        stakers[msg.sender] = block.number;
        rewards[msg.sender] = fees;
        staked += balance[msg.sender];

        emit Stake(msg.sender);
    }

    function claimPending() public view returns (uint) {
        uint val = bonuses[msg.sender];
        if (staked > 0) {
            if (balance[msg.sender] < staked) {
              val += ((fees - rewards[msg.sender]) * balance[msg.sender] / staked);
            }
            else {
              val += (fees - rewards[msg.sender]);
            }
        }

        return val;
    }

    function claim() public {
        require(control());
        require(stakers[msg.sender] > 0, "Staking not active.");

        uint val = bonuses[msg.sender];
        if (staked > 0) {
            if (balance[msg.sender] < staked) {
              val += ((fees - rewards[msg.sender]) * balance[msg.sender] / staked);
            }
            else {
              val += (fees - rewards[msg.sender]);
            }
        }

        if (val > 0) {
            vsdc.mint(msg.sender, val);
            rewards[msg.sender] = fees;
            bonuses[msg.sender] = 0;
        }
    }

    function unstake() public {
        require(control());
        require(block.number - stakers[msg.sender] > (bir / 3), "Staking still active. Wait longer."); // 4 months

        claim();
        stakers[msg.sender] = 0;
        if (staked > balance[msg.sender]) {
          staked -= balance[msg.sender];
        }
        else {
          staked = 0;
        }

        emit Unstake(msg.sender);
    }

    function burnFrom(address src, uint wad) public {
        require(minters[msg.sender] == true);
        require(balance[src] >= wad, "No balance");

        if (src != msg.sender && allowance[src][msg.sender] != MAX_INT) {
            require(allowance[src][msg.sender] >= wad, "No allowance");
            allowance[src][msg.sender] -= wad;
        }

        supply -= wad;
        balance[src] -= wad;

        if (stakers[src] > 0) {
            if (staked > wad) {
              staked -= wad;
            }
            else {
              staked = 0;
            }
        }
        
        emit Transfer(src, address(0), wad);
    }

    function collect(uint wad, address ref) public {
        require(minters[msg.sender] == true);

        if (wad >= 4) {
            uint half = (wad / 2);
            uint quarter = (wad / 4);

            fees += half;

            if (ref != address(0) && ref != msg.sender) {
                bonuses[ref] += quarter;
                bonuses[chest] += quarter;
            }
            else {
                bonuses[chest] += half;
            }
        }
    }

    function collect(uint wad) public {
        collect(wad, address(0));
    }

    function rewardsOf(address usr) public view returns (uint) {
        return ((fees - rewards[usr]) * balance[usr] / supply) + bonuses[usr];
    }

    function totalSupply() public view returns (uint) {
        return supply;
    }

    function balanceOf(address usr) public view returns (uint) {
        return balance[usr];
    }

    function approve(address usr, uint wad) public returns (bool) {
        allowance[msg.sender][usr] = wad;

        emit Approval(msg.sender, usr, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        require(stakers[msg.sender] == 0, "Staking active.");
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad) public returns (bool) {
        require(balance[src] >= wad, "No balance");
        require(stakers[src] == 0, "Staking active.");

        if (src != msg.sender && allowance[src][msg.sender] != MAX_INT) {
            require(allowance[src][msg.sender] >= wad, "No allowance");
            allowance[src][msg.sender] -= wad;
        }

        balance[src] -= wad;
        balance[dst] += wad;

        emit Transfer(src, dst, wad);
        return true;
    }

    function burn(uint wad) public {
        burnFrom(msg.sender, wad);
    }

    function lock() public {
        require(LOCKED == false, "Lock already active. Unlock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");

        LOCKED = true;
        TIMELOCK = 0;

        emit Lock(msg.sender);
    }
    
    function grace() public {
        require(LOCKED == true, "Lock must be active. Lock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");

        TIMELOCK = block.timestamp + 7 days;

        emit Grace(msg.sender);
    }

    function unlock() public {
        require(LOCKED == true, "Lock must be active. Lock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");
        require(TIMELOCK < block.timestamp, "Timelock still active. Wait longer.");

        LOCKED = false;

        emit Unlock(msg.sender);
    }
    

    function addOwner(address usr) public {
        require(LOCKED == false, "Lock must be inactive. Unlock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");

        owners[usr] = true;

        emit AddOwner(msg.sender, usr);
    }

    function removeOwner(address usr) public {
        require(LOCKED == false, "Lock must be inactive. Unlock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");

        owners[usr] = false;

        emit RemoveOwner(msg.sender, usr);
    }

    function addMinter(address usr) public {
        require(LOCKED == false, "Lock must be inactive. Unlock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");

        minters[usr] = true;

        emit AddMinter(msg.sender, usr);
    }

    function removeMinter(address usr) public {
        require(LOCKED == false, "Lock must be inactive. Unlock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");

        minters[usr] = false;

        emit RemoveMinter(msg.sender, usr);
    }

    function updateChest(address adr) public {
        require(LOCKED == false, "Lock must be inactive. Unlock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");

        chest = adr;

        emit UpdateChest(msg.sender, adr);
    }

    function init() public {
        require(INIT == false, "Init already called.");
        require(LOCKED == false, "Lock must be inactive. Unlock first.");
        require(owners[msg.sender] == true, "Function available to owners only.");

        airdrop(0xF55d7A2F553Be0bEAEDcE903103a2a13e9b5508C,4526342034*1e12);
        airdrop(0xf0b699A8559A3fFAf72f1525aBe14CebcD1De5Ed,1266205493*1e12);
        airdrop(0xa2f632cc085C3604e080E09812658c5696b1A81f,1120021259*1e12);
        airdrop(0x1727bA5e37209CEE3793b87C49c6E89A6A63B695,826275236*1e12);
        airdrop(0x78B864A7bcE3888460Ae9793B827cE521AC0d7Bf,428599152*1e12);
        airdrop(0xC0a4Cc4fbF2E85963555B3b86ED96b9842c76523,362891926*1e12);
        airdrop(0x6B5e3557d0E06815cb2FDcC62888df896d2eF2f1,359084834*1e12);
        airdrop(0xe8E1696A764A0170aa6505D8c633a955aE32233B,300000000*1e12);
        airdrop(0x06bc3AFC4E030ebA27F6d538BD5d76500691184D,250561963*1e12);
        airdrop(0xfb6DF6Dc12D9006E276D63D6870321269Eff44b1,200000000*1e12);
        airdrop(0xCD4c331A1d29eC2c96Ca8E439005e80C0d15E6a3,197222687*1e12);
        airdrop(0xd05433Ec8910EE00b4FD5222499ee70A5763798C,187268816*1e12);
        airdrop(0x9Dfe88d246B6BD9BfC84Aeee7ba7938441D3f994,153381539*1e12);
        airdrop(0x049A2765b889E7d4529f2FEEE304171fF1BB0568,115554428*1e12);
        airdrop(0xc4f88C35Bd1485C846847C093B5a77a126cf1b05,108350262*1e12);
        airdrop(0x5f303E3d5c220a49FBa3f53E502Eb4abd0Be607A,71637258*1e12);
        airdrop(0x861FEF90b079d581002A73d6B4C2059a62b01711,68927647*1e12);
        airdrop(0xCD6622B78B16ab217809f6089c410442a84869E6,60420463*1e12);
        airdrop(0x59464d45D3dC988a390d4895f049a10CaB5EE7d3,57019567*1e12);
        airdrop(0x7dfF2584757ADd4150210295bD11dba7F72ED8B3,48494869*1e12);
        airdrop(0xd374893F994F81E0AA555b21CF703fF6d8b51B03,40656870*1e12);
        airdrop(0xD0357157fe04f7D6F6D75E45301dDd2264D3CaD6,40000000*1e12);
        airdrop(0x73024F4C577ded086CCf97921c51286F8ed1Ce86,14075717*1e12);
        airdrop(0x901f253Fc9FE429A3FbFb8a0A4a7280Fb2a78b4B,10768052*1e12);
        airdrop(0x8A2D26F44075a3B9f2aE0615a5bbbE6f4d0616cE,9688056*1e12);
        airdrop(0x448a6e3e4C02Df62fc8D9817F9817AdD26d706d0,7020873*1e12);
        airdrop(0x36c1F88c4C1B540A3b5a3f9e8A0cd6F4f134aE42,4720284*1e12);
        airdrop(0x34DB505B2E6D9a5195f0079aD2E36B6D9F5B267B,3298412*1e12);
        airdrop(0x52bbb9C9412bDBf23444498Badd15Bf76E531E66,3193262*1e12);
        airdrop(0xc0Effcf4c6fCf5F37f73F7A311391dd56AC7d9Fe,3162221*1e12);
        airdrop(0xa057d4aBad0cF826fA03f310155a77DCDFceFCf8,3000000*1e12);
        airdrop(0xe2a0FA6B74426DA3c3778AEFA0Ca4C9c8ca863aE,2502559*1e12);
        airdrop(0x95b78c3De524F050717338d6DC67f77f928Bfed1,2406708*1e12);
        airdrop(0x2C826f6D49d58EBFc5E45906be9Eae3Fc7cA71dc,2305291*1e12);
        airdrop(0x35F2E1D3a99C3fd78CD26DB53960833B994448ea,2000000*1e12);
        airdrop(0x2D407dDb06311396fE14D4b49da5F0471447d45C,2000000*1e12);
        airdrop(0x974896E96219Dd508100f2Ad58921290655072aD,2000000*1e12);
        airdrop(0x531D8846Ee2cFf18b98Ff0455ac5F7F28015538d,1850000*1e12);
        airdrop(0x9008D19f58AAbD9eD0D60971565AA8510560ab41,1752364*1e12);
        airdrop(0x5D6c311256c799cB634068DEFc56875cD0F065A7,1663026*1e12);
        airdrop(0x88f7091C4307C5d85E97b5a3f3113BE780093d77,1500000*1e12);
        airdrop(0x1A53a9e4C29FED9cFDb10a70B91B7aC34DEd6956,1146531*1e12);
        airdrop(0x9AAe0e6F5910D003e7cA56716684A400f5FB5a2E,1112953*1e12);
        airdrop(0x2F352Bbb6C074751d0F384Dd1Cc63AAC4aa81872,1015548*1e12);
        airdrop(0xC0BCD6D3ea3D2723c400D8F49788CFb8Eb565c1b,1000000*1e12);
        airdrop(0x95551cf63f5794287AB2aB4ffdb3b07b3Df31702,1000000*1e12);
        airdrop(0x2215AdFC818b090A69A84ae6C453Afa67264fB8d,1000000*1e12);
        airdrop(0x236E3f5d79a03e4a64ff639379Dc23739D140919,1000000*1e12);
        airdrop(0xe42Ff47Bf38701d966ae79Ad7dF1a8Ed6B97A441,985165*1e12);
        airdrop(0xA1ffC697E1916bAbC81Aa97a98a02a8A78735308,903812*1e12);
        airdrop(0x44c00DF0f0986083fd5e6D102A459F23f9da520f,893365*1e12);
        airdrop(0xD0da7989BAFcfEE74aEB400832e1ac45821eB197,768593*1e12);
        airdrop(0x49ED6b5343d7b88170e7Bc65EccC4AB5BA3B1774,553154*1e12);
        airdrop(0x0A0c806D932FAC1c4Bbb4A8A1EC8045E2Ff28545,500000*1e12);
        airdrop(0x4Fe82cF031905f07C9D95b3BF2Ff7675a4d00bd7,500000*1e12);
        airdrop(0xA572e779Bb62de2AFA116E8A4283aC84a3149bC9,500000*1e12);
        airdrop(0x23D3a224F4bc81e03aA5Ed54f240C6343C5Db8a3,474528*1e12);
        airdrop(0xc9C54c13b74dDccDd62052A1FD3CCf4f5B50539A,442408*1e12);
        airdrop(0x6AE33b1600c9Ed2254313f53F15566B7c53b5d1d,433860*1e12);
        airdrop(0x70279891dc0cAdC733413f3c104FB197DF55EdB9,430064*1e12);
        airdrop(0x0f07CAca710368e94dC5bb279210523C4ab16EB9,410000*1e12);
        airdrop(0x9466ebf24B2761FBa6CbFd7F93d306c017325dE7,408535*1e12);
        airdrop(0x4EE64F355b29C4578CBf70585E8e73e2b1eeAcC1,360809*1e12);
        airdrop(0xA5d31a3Ed981eC2fC2b10987Be0dD04Dfc6b8c38,355602*1e12);
        airdrop(0x6E82a63739B30Ec39ae5928FD7f2e3b292623726,345210*1e12);
        airdrop(0x9ad48187123ce43171b9D9DA2EeAB755A568fb0b,316500*1e12);
        airdrop(0xB8F0919480714a15356deF3F04F8E5a2D56498E7,300000*1e12);
        airdrop(0xD8d1d6f7Fad4eBCAEd2b2850dFC45DD93090eEb6,299430*1e12);
        airdrop(0xaD81C90131f4A10f5D324164f4406dC43c962d37,294295*1e12);
        airdrop(0xd834bBD00631460a6fE100574fdDb0628e463316,293301*1e12);
        airdrop(0x2781a0b97FdCc80E7b7CA9bE6eEAF6c4eeCFd13A,290153*1e12);
        airdrop(0x440DfDe237a0940DC3b85A230F2E03f70B463E65,221182*1e12);
        airdrop(0x3015a82638c8714F0C4D47FDD934839e2D1550DB,213670*1e12);
        airdrop(0x524F645F5dbDe7F60a4372B4c303d87917906810,202501*1e12);
        airdrop(0xa8dB9Ba6E8CA63d4D7DC035880e1E9Abde6051C4,200818*1e12);
        airdrop(0x11eDedebF63bef0ea2d2D071bdF88F71543ec6fB,179047*1e12);
        airdrop(0xc9540Ac5e0336910AECAF67Fe86482DD709f291e,177861*1e12);
        airdrop(0x77F83B95cB6081eACbBb3F479b4c206a102daec3,175575*1e12);
        airdrop(0x2e239C61D5a77e7152F26DC4f20D1c314CafABAa,132527*1e12);
        airdrop(0x1202c3892f29e74151448A63fd5d080910aC9a7C,124687*1e12);
        airdrop(0x00a7115685d9d7007360C562C01CE72a1EfB9a24,100000*1e12);
        airdrop(0x9C2514B7A19524e24e48459980aAFF485b3b920d,100000*1e12);
        airdrop(0xe6770b5C8b16cF777c17b0D4e064f11E1C378e30,64686*1e12);
        airdrop(0x8d7EC18D94e680Ec4D6F39d2c8Ef90447AE29cB8,40676*1e12);
        airdrop(0x73282A63F0e3D7e9604575420F777361ecA3C86A,17000*1e12);
        airdrop(0xF2D54033190bbc5a322cb93c7B36c65670D63264,12672*1e12);
        airdrop(0xF74Bf048138a2B8F825ECCaBed9e02E481A0F6C0,10000*1e12);
        airdrop(0x56D9f9113eC1B60DdAa9241d5aEC69587cCc729C,9638*1e12);
        airdrop(0xbA1c0d8447145B6B5367448fC65027898208607c,5903*1e12);
        airdrop(0x4Db4683485A116381E363a6DAf5427d70DAcb68b,2450*1e12);
        airdrop(0x53F4dc9c59443E77275D4e4529a653cEA3721A7d,1084*1e12);
        airdrop(0x9c73AB276E6588764ff185c4B34287205b32Ae6d,1000*1e12);
        airdrop(0x9C4B76B235a82EFd83C0d26D179afDfCeED9E0d7,852*1e12);
        airdrop(0x37866B41703aAd3D2536A2a17e2E520f2B28FDb7,729*1e12);
        airdrop(0xA1a41029ca71cbCf686975f89e773d0f796b2e64,598*1e12);
        airdrop(0x69368e32C148817aCd9FD7dbeBf0a0aF4Df20E51,508*1e12);
        airdrop(0xB086755a5B0b10BD53956936588555f586f5f49d,6*1e12);
        airdrop(0xA6D6A1320fE6e26474b74623d4cDC02BA56073b1,6*1e12);
        airdrop(0x4b14aa5c7b8bF64897902a8480e5A8A01982541d,1*1e12);

        INIT = true;
    }
}
