import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Principal "mo:base/Principal";

import CkBTCAddress "../src";

// hardcoded keys for ckBtc minter canister
let minter = CkBTCAddress.Minter({
  public_key = "\02\22\04\7A\81\D4\F8\A0\67\03\1C\89\27\3D\24\1B\79\A5\A0\07\C0\4D\FA\F3\6D\07\96\3D\B0\B9\90\97\EB";
  chain_code = "\82\1A\EB\B6\43\BD\97\D3\19\D2\FD\0B\2E\48\3D\4E\7D\E2\EA\90\39\FF\67\56\8B\69\3E\6A\BC\14\A0\3B";
});

func user_to_subaccount(user : Principal) : Blob {
  let b = Principal.toBlob(user);
  let l = b.size();
  assert l <= 31;
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
let f_3gvau = minter.deposit_addr_func(Principal.fromText("3gvau-pyaaa-aaaao-qa7kq-cai"));
let f_farwr = minter.deposit_addr_func(Principal.fromText("farwr-jqaaa-aaaao-qj4ya-cai"));

do {
  "2vxsx-fae"
  |> Principal.fromText(_)
  |> user_to_subaccount(_)
  |> f_3gvau(?_)
  |> (assert _ == "bc1q9q0kg90px3w9dadxku2x5pme77plcqxtn535rt");
};

do {
  "gjcgk-x4xlt-6dzvd-q3mrr-pvgj5-5bjoe-beege-n4b7d-7hna5-pa5uq-5qe"
  |> Principal.fromText(_)
  |> user_to_subaccount(_)
  |> f_3gvau(?_)
  |> (assert _ == "bc1qvxx6fzd8hzzw070zsd5m0k0eh00593negrvtrj");
};

do {
  "2vxsx-fae"
  |> Principal.fromText(_)
  |> user_to_subaccount(_)
  |> f_farwr(?_)
  |> (assert _ == "bc1q7grqgee386r6qf74srt4h0s69cvkav7kgup4l7");
};

do {
  "mgqao-xam3j-a3ruc-umodo-tnifj-sszm7-7lilh-aibsy-2u7uz-gwph7-jae" // seed "qre"
  |> Principal.fromText(_)
  |> user_to_subaccount(_)
  |> f_farwr(?_)
  |> (assert _ == "bc1qpamdxt8rx5lr256dq7u4dnua02tlrdwyeerzwx");
};

do {
  "rl3fy-hyflm-6r3qg-7nid5-lr6cp-ysfwh-xiqme-stgsq-bcga5-vnztf-mqe" // seed "123qwe"
  |> Principal.fromText(_)
  |> user_to_subaccount(_)
  |> f_farwr(?_)
  |> (assert _ == "bc1qxzlu00s4k83ts763s57xz89n3tnwfm3q6z3pt8");
};
