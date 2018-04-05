pragma solidity ^0.4.20;

import "ds-test/test.sol";
import "ds-token/token.sol";

import './frob.sol';

import {WarpFlip as Flipper} from './flip.t.sol';
import {WarpFlop as Flopper} from './flop.t.sol';
import {WarpFlap as Flapper} from './flap.t.sol';


contract Pie is DSToken("PIE") {
    function flex(address guy, int wad) public {
        if (wad > 0) mint(guy, uint( wad));
        if (wad < 0) burn(guy, uint(-wad));
    }
    function suck(uint wad) public {
        this.mint(msg.sender, wad);
    }
}

contract WarpBin is Bin {
    uint48 _era; function warp(uint48 era_) public { _era = era_; }
    function era() internal view returns (uint48) { return _era; }
    function WarpBin(address pie_, address flapper_, address flopper_)
        public Bin(pie_, flapper_, flopper_) {}
}

contract FrobTest is DSTest {
    WarpBin bin;
    Pie     pie;

    DSToken gold;
    bytes32 gold_ilk;

    Flipper flip;
    Flopper flop;
    Flapper flap;

    DSToken gov;

    function try_frob(bytes32 ilk, uint ink, uint art) public returns(bool) {
        bytes4 sig = bytes4(keccak256("frob(bytes32,uint256,uint256)"));
        return bin.call(sig, ilk, ink, art);
    }

    function ray(uint wad) internal pure returns (uint) {
        return wad * 10 ** 9;
    }

    function setUp() public {
        pie = new Pie();
        gov = new DSToken('GOV');
        gov.mint(100 ether);

        flap = new Flapper(pie, gov);
        flop = new Flopper(pie, gov);
        gov.setOwner(flop);

        bin = new WarpBin(pie, flap, flop);
        pie.setOwner(bin);

        gold = new DSToken("GEM");
        gold.mint(1000 ether);

        gold_ilk = bin.form(gold);
        bin.file(gold_ilk, "spot", ray(1 ether));
        bin.file(gold_ilk, "line", ray(1 ether));
        flip = new Flipper(bin, gold_ilk, pie, gold);
        bin.fuss(gold_ilk, flip);

        pie.approve(bin);
        gold.approve(bin);
        pie.approve(flip);
        pie.approve(flop);
        gov.approve(flap);
    }

    function test_lock() public {
        assertEq(gold.balanceOf(this),  1000 ether);
        bin.frob(gold_ilk, 6 ether, 0);
        assertEq(gold.balanceOf(this),   994 ether);
        bin.frob(gold_ilk, 0 ether, 0);
        assertEq(gold.balanceOf(this),  1000 ether);
    }
    function test_calm() public {
        // calm means that the debt ceiling is not exceeded
        // it's ok to increase debt as long as you remain calm
        bin.file(gold_ilk, 'line', 10 ether);
        assertTrue( try_frob(gold_ilk, 10 ether, 9 ether));
        // only if under debt ceiling
        assertTrue(!try_frob(gold_ilk, 10 ether, 11 ether));
    }
    function test_cool() public {
        // cool means that the debt has decreased
        // it's ok to be over the debt ceiling as long as you're cool
        bin.file(gold_ilk, 'line', 10 ether);
        assertTrue(try_frob(gold_ilk, 10 ether, 8 ether));
        bin.file(gold_ilk, 'line', 5 ether);
        // can decrease debt when over ceiling
        assertTrue(try_frob(gold_ilk, 10 ether, 7 ether));
    }
    function test_safe() public {
        // safe means that the cdp is not risky
        // you can't frob a cdp into unsafe
        bin.frob(gold_ilk, 10 ether, 5 ether);                // safe draw
        assertTrue(!try_frob(gold_ilk, 10 ether, 11 ether));  // unsafe draw
    }
    function test_nice() public {
        // nice means that the risk has decreased
        // remaining unsafe is ok as long as you're nice

        bin.frob(gold_ilk, 10 ether, 10 ether);
        bin.file(gold_ilk, 'spot', ray(0.5 ether));  // now unsafe

        // debt can't increase if unsafe
        assertTrue(!try_frob(gold_ilk, 10 ether, 11 ether));
        // debt can decrease
        assertTrue( try_frob(gold_ilk, 10 ether,  9 ether));
        // ink can't decrease
        assertTrue(!try_frob(gold_ilk,  9 ether,  9 ether));
        // ink can increase
        assertTrue( try_frob(gold_ilk, 11 ether,  9 ether));
        // ink can decrease if debt decreases more
        assertTrue(!try_frob(gold_ilk,  9 ether,  8 ether));
        assertTrue( try_frob(gold_ilk, 10 ether,  8 ether));
        // debt can increase if ink increases more
        assertTrue(!try_frob(gold_ilk, 11 ether,  9 ether));
        assertTrue( try_frob(gold_ilk, 12 ether,  9 ether));
    }

    function test_happy_bite() public {
        // spot = tag / (par . mat)
        // tag=5, mat=2
        bin.file(gold_ilk, 'spot', ray(2.5 ether));
        bin.frob(gold_ilk,  40 ether, 100 ether);

        // tag=4, mat=2
        bin.file(gold_ilk, 'spot', ray(2 ether));  // now unsafe

        assertEq(bin.get_ink(gold_ilk, this),  40 ether);
        assertEq(bin.get_art(gold_ilk, this), 100 ether);
        assertEq(bin.woe(), 0 ether);
        assertEq(gold.balanceOf(bin), 40 ether);
        uint auction = bin.bite(gold_ilk, this);
        assertEq(bin.get_ink(gold_ilk, this), 0);
        assertEq(bin.get_art(gold_ilk, this), 0);
        assertEq(bin.woe(), 100 ether);
        assertEq(gold.balanceOf(bin),  0 ether);

        assertEq(pie.balanceOf(bin),   0 ether);
        flip.tend(auction, 40 ether,   1 ether);
        assertEq(pie.balanceOf(bin),   1 ether);
        flip.tend(auction, 40 ether, 100 ether);
        assertEq(pie.balanceOf(bin), 100 ether);

        assertEq(pie.balanceOf(this), 0 ether);
        assertEq(gold.balanceOf(bin), 0 ether);
        pie.suck(100 ether);  // magic up some pie for bidding
        flip.dent(auction, 39 ether,  100 ether);
        assertEq(pie.balanceOf(this), 100 ether);
        assertEq(pie.balanceOf(bin),  100 ether);
        assertEq(gold.balanceOf(bin),   1 ether);

        assertEq(bin.get_ink(gold_ilk, this), 1 ether);

        assertEq(bin.woe(), 100 ether);
        assertEq(pie.balanceOf(bin), 100 ether);
        bin.heal(100 ether);
        assertEq(bin.woe(), 0 ether);
        assertEq(pie.balanceOf(bin), 0 ether);
    }

    function test_floppy_bite() public {
        bin.file(gold_ilk, 'spot', ray(2.5 ether));
        bin.frob(gold_ilk,  40 ether, 100 ether);
        bin.file(gold_ilk, 'spot', ray(2 ether));  // now unsafe
        bin.bite(gold_ilk, this);
        assertEq(bin.woe(), 100 ether);

        uint f1 = bin.flop(10 ether);
        assertEq(pie.balanceOf(bin), 0 ether);
        flop.dent(f1, 1000 ether, 10 ether);
        assertEq(pie.balanceOf(bin), 10 ether);

        assertEq(gov.balanceOf(this),  100 ether);
        flop.warp(4 hours);
        flop.deal(f1);
        assertEq(gov.balanceOf(this), 1100 ether);
    }

    function test_flappy_bite() public {
        // get some surplus
        pie.suck(100 ether);
        pie.push(bin, 100 ether);

        assertEq(gov.balanceOf(this),  100 ether);
        uint id = bin.flap(100 ether);

        assertEq(pie.balanceOf(this),   0 ether);
        assertEq(gov.balanceOf(this), 100 ether);
        flap.tend(id, 100 ether, 10 ether);
        flap.warp(4 hours);
        flap.deal(id);
        assertEq(pie.balanceOf(this), 100 ether);
        assertEq(gov.balanceOf(this),  90 ether);
    }
}
