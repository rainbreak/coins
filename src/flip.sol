pragma solidity ^0.4.20;

contract GemLike {
    function move(address,address,uint) public;
    function approve(address) public;
}

contract VatLike {
    function bump(bytes32,address,uint) public;
}


/*
   This thing lets you flip some gems for a given amount of pie.
   Once the given amount of pie is raised, gems are forgone instead.

 - `lot` gems for sale
 - `tab` total pie wanted
 - `bid` pie paid
 - `gal` receives pie income
 - `lad` receives gem forgone
 - `ttl` single bid lifetime
 - `beg` minimum bid increase
 - `end` max auction duration
*/

contract Flipper {
    GemLike public pie;
    GemLike public gem;
    VatLike public bin;
    bytes32 public ilk;

    uint256 public beg = 1.05 ether;  // 5% minimum bid increase
    uint48  public ttl = 3.00 hours;  // 3 hours bid duration
    uint48  public tau = 1 weeks;     // 1 week total auction length

    uint256 public kicks;

    struct Bid {
        uint256 bid;
        uint256 lot;
        address guy;  // high bidder
        uint48  tic;  // time of last bid
        uint48  end;
        address lad;
        address gal;
        uint256 tab;
    }

    mapping (uint => Bid) public bids;

    function era() internal view returns (uint48) { return uint48(now); }

    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    uint constant WAD = 10 ** 18;
    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function Flipper(address bin_, bytes32 ilk_, address pie_, address gem_) public {
        ilk = ilk_;
        bin = VatLike(bin_);
        pie = GemLike(pie_);
        gem = GemLike(gem_);
        gem . approve(bin);
    }

    function kick(address lad, address gal, uint tab, uint lot, uint bid)
        public returns (uint)
    {
        uint id = ++kicks;
        gem.move(msg.sender, this, lot);

        bids[id].bid = bid;
        bids[id].lot = lot;
        bids[id].guy = msg.sender; // configurable??
        bids[id].end = era() + tau;
        bids[id].lad = lad;
        bids[id].gal = gal;
        bids[id].tab = tab;

        return id;
    }
    function tend(uint id, uint lot, uint bid) public {
        require(bids[id].guy != 0);
        require(bids[id].tic > era() || bids[id].tic == 0);
        require(bids[id].end > era());
        require(bid >= wmul(beg, bids[id].bid) ||
                bid == bids[id].tab            ||
                msg.sender == bids[id].guy);
        require(bid <= bids[id].tab);
        require(lot == bids[id].lot);

        pie.move(msg.sender, bids[id].guy, bids[id].bid);
        pie.move(msg.sender, bids[id].gal, bid - bids[id].bid);

        bids[id].guy = msg.sender;
        bids[id].bid = bid;
        bids[id].tic = era() + ttl;
    }
    function dent(uint id, uint lot, uint bid) public {
        require(bids[id].guy != 0);
        require(bids[id].tic > era() || bids[id].tic == 0);
        require(bids[id].end > era());
        require(bid == bids[id].bid);
        require(bid == bids[id].tab);
        require(wmul(beg, lot) <= bids[id].lot || msg.sender == bids[id].guy);

        pie.move(msg.sender, bids[id].guy, bid);
        bin.bump(ilk, bids[id].lad, bids[id].lot - lot);

        bids[id].guy = msg.sender;
        bids[id].lot = lot;
        bids[id].tic = era() + ttl;
    }
    function deal(uint id) public {
        require(bids[id].tic < era() && bids[id].tic != 0 ||
                bids[id].end < era());
        gem.move(this, bids[id].guy, bids[id].lot);
        delete bids[id];
    }
}
