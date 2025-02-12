import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Prim "mo:prim";
import Principal "mo:base/Principal";

import Bench "mo:bench";

import CkBtcAddress "../src";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Address calculation");
    bench.description("Calculate BTC deposit address for given account");

    bench.rows(["Empty subaccount", "Set subaccount"]);
    bench.cols(["Pre-set owner", "Set owner"]);

    let addr = CkBtcAddress.Minter({
      public_key : Blob = "\02\22\04\7A\81\D4\F8\A0\67\03\1C\89\27\3D\24\1B\79\A5\A0\07\C0\4D\FA\F3\6D\07\96\3D\B0\B9\90\97\EB";
      chain_code : Blob = "\82\1A\EB\B6\43\BD\97\D3\19\D2\FD\0B\2E\48\3D\4E\7D\E2\EA\90\39\FF\67\56\8B\69\3E\6A\BC\14\A0\3B";
    });

    let owner : Principal = Principal.fromText("s7rux-5qw2w-h6o7j-dhwoh-xq4l2-xgl53-satjs-2eqwz-xgeex-a2vp2-yqe");
    let sa : ?Blob = ?Blob.fromArray(Array.tabulate<Nat8>(32, func(n) = Nat8.fromIntWrap(n)));

    let subaccountAddressFunc = addr.deposit_addr_func(owner);

    bench.runner(
      func(row, col) {
        let subaccount : ?Blob = switch (row) {
          case "Empty subaccount" null;
          case "Set subaccount" sa;
          case _ Prim.trap("");
        };
        switch (col) {
          case "Pre-set owner" ignore subaccountAddressFunc(subaccount);
          case "Set owner" ignore addr.deposit_addr({ owner; subaccount });
          case _ Prim.trap("");
        };
      }
    );

    bench;
  };
};
