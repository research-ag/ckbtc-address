import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";

import CkBTCAddress "../src";

let addr = CkBTCAddress.CkBTCAddress(Principal.fromText("mqygn-kiaaa-aaaar-qaadq-cai"));
// hardcoded keys for ckBtc minter canister
addr.setKeys(
  "\02\22\04\7A\81\D4\F8\A0\67\03\1C\89\27\3D\24\1B\79\A5\A0\07\C0\4D\FA\F3\6D\07\96\3D\B0\B9\90\97\EB",
  "\82\1A\EB\B6\43\BD\97\D3\19\D2\FD\0B\2E\48\3D\4E\7D\E2\EA\90\39\FF\67\56\8B\69\3E\6A\BC\14\A0\3B",
);

func user_to_subaccount(user : Principal) : Blob {
  let b = Principal.toBlob(user);
  let l = b.size();
  assert l <= 32;
  let r = Array.init<Nat8>(32, 0);
  var i : Nat = 32 - l;
  r[i - 1] := Nat8.fromNat(l);
  for (v in b.vals()) {
    r[i] := v;
    i += 1;
  };
  Blob.fromArrayMut(r);
};

// get deposit address for a user of the auction backend
func get_user_deposit_addr(user : Principal) : Text {
  user
  |> user_to_subaccount(_)
  |> addr.get_deposit_addr({
    owner = Principal.fromText("3gvau-pyaaa-aaaao-qa7kq-cai");
    subaccount = ?_;
  });
};

do {
  "2vxsx-fae"
  |> get_user_deposit_addr(Principal.fromText(_))
  |> (assert _ == "bc1q9q0kg90px3w9dadxku2x5pme77plcqxtn535rt");
};

do {
  "gjcgk-x4xlt-6dzvd-q3mrr-pvgj5-5bjoe-beege-n4b7d-7hna5-pa5uq-5qe"
  |> get_user_deposit_addr(Principal.fromText(_))
  |> (assert _ == "bc1qvxx6fzd8hzzw070zsd5m0k0eh00593negrvtrj");
};
