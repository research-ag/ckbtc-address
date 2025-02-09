import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Common "mo:bitcoin/Common";
import Segwit "mo:bitcoin/Segwit";
import Hmac "mo:bitcoin/Hmac";
import Hash "mo:bitcoin/Hash";
import Curves "mo:bitcoin/ec/Curves";
import Jacobi "mo:bitcoin/ec/Jacobi";

// The master extended public key of the ckBTC minter
// It was obtained by running this code in a canister:
// https://play.motoko.org/?tag=1890044230
let minter_pubkey = Blob.toArray("\02\22\04\7A\81\D4\F8\A0\67\03\1C\89\27\3D\24\1B\79\A5\A0\07\C0\4D\FA\F3\6D\07\96\3D\B0\B9\90\97\EB");
let minter_chaincode = Blob.toArray("\82\1A\EB\B6\43\BD\97\D3\19\D2\FD\0B\2E\48\3D\4E\7D\E2\EA\90\39\FF\67\56\8B\69\3E\6A\BC\14\A0\3B");

// The following is a modified version of the class ExtendedPublicKey
// from https://github.com/dfinity/motoko-bitcoin/blob/main/src/Bip32.mo
// The modifications are:
// - remove unneeded fields depth, index, parentPublicKey
// - generalize path from [Nat32] to [Blob]
type Path = [Blob];
let curve : Curves.Curve = Curves.secp256k1;

class ExtendedPublicKey(
  _key : [Nat8],
  _chaincode : [Nat8],
) {

  public let key = _key;
  public let chaincode = _chaincode;

  // Derive a child public key with path relative to this instance. Returns
  // null if path is #text and cannot be parsed.
  public func derivePath(path : Path) : ExtendedPublicKey {
    var target : ExtendedPublicKey = ExtendedPublicKey(
      key,
      chaincode,
    );

    // Derive the hierarchy of child keys.
    for (childIndex in path.vals()) {
      target := target.deriveChild(childIndex);
    };
    target;
  };

  // Derive child at the given index. Valid indices are blobs.
  public func deriveChild(index : Blob) : ExtendedPublicKey {

    // Compute HMAC with chaincode as the key and the serialized
    // parentPublicKey (33 bytes) concatenated with the index
    // as its data.
    let hmacData : [var Nat8] = Array.init<Nat8>(33 + index.size(), 0x00);
    Common.copy(hmacData, 0, key, 0, 33);
    Common.copy(hmacData, 33, Blob.toArray(index), 0, index.size());
    let hmacSha512 : Hmac.Hmac = Hmac.sha512(chaincode);
    hmacSha512.writeArray(Array.freeze(hmacData));
    let fullNode : [Nat8] = Blob.toArray(hmacSha512.sum());

    // Split HMAC output into two 32-byte sequences.
    let left : [Nat8] = Array.tabulate<Nat8>(
      32,
      func(i) {
        fullNode[i];
      },
    );
    let right : [Nat8] = Array.tabulate<Nat8>(
      32,
      func(i) {
        fullNode[i + 32];
      },
    );

    // Parse the left 32-bytes as an integer in the domain parameters of
    // secp2secp256k1 curve.
    let multiplicand : Nat = Common.readBE256(left, 0);
    if (multiplicand >= curve.r) {
      // This has probability lower than 1 in 2^127.
      Debug.trap("derivation failed");
    };

    switch (Jacobi.fromBytes(key, curve)) {
      case (null) Debug.trap("derivation failed");
      case (?parsedKey) {
        // Derive the child public key.
        switch (Jacobi.add(Jacobi.mulBase(multiplicand, curve), parsedKey)) {
          case (#infinity(_)) Debug.trap("derivation failed");
          case (childPublicKey) {
            return ExtendedPublicKey(
              Jacobi.toBytes(childPublicKey, true),
              right,
            );
          };
        };
      };
    };
  };

  // convert pubkey to a p2wpkh (Segwit) Bitcoin address
  public func pubkey_address() : Text {
    switch (Segwit.encode("bc", { version = 0; program = Hash.hash160(key) })) {
      case (#ok addr) return addr;
      case (#err e) Debug.trap(e);
    };
  };
};

// Now we can use the modified version

// minter public key
let p0 = ExtendedPublicKey(minter_pubkey, minter_chaincode);

// The derivation path for a deposit address is: [1, owner, subaccount]
// We pre-calculate the first step (1) because it is the same for all
// paths that we will use.
// It can be calculated with
//  let p1 = p0.deriveChild("\01");
// but we hard-code it.
let p1 = ExtendedPublicKey(
  [2, 244, 91, 146, 204, 204, 82, 220, 134, 205, 58, 38, 113, 226, 123, 209, 79, 168, 185, 214, 96, 230, 138, 178, 22, 3, 127, 129, 212, 213, 141, 42, 132],
  [84, 48, 87, 99, 118, 33, 11, 96, 35, 146, 171, 214, 48, 96, 129, 229, 150, 109, 161, 223, 19, 78, 85, 143, 62, 60, 82, 204, 67, 28, 82, 232],
);

// Get the ckBTC minter's deposit address for account
func get_deposit_addr(account : { owner : Principal; subaccount : ?Blob }) : Text {
  [
    Principal.toBlob(account.owner),
    Option.get(account.subaccount, "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob),
  ]
  |> p1.derivePath(_)
  |> _.pubkey_address();
};

// The test vectors can be reproduced with https://play.motoko.org/?tag=1890044230
// by calling get_btc_address() with the same arguments
do {
  // deposit for anonymous principal
  {
    owner = Principal.fromText("2vxsx-fae");
    subaccount = null;
  }
  |> get_deposit_addr(_)
  |> (assert _ == "bc1q7ecd9c4vh8efh8v9pyz5jzz2glr22wxvxav7d3");
};

// Second step derived key for deposits to auction backend
// It can calculated with
//   let p2 = p1.deriveChild(
//     Principal.toBlob(Principal.fromText("3gvau-pyaaa-aaaao-qa7kq-cai"))
//   );
// but we hard-code it.
let p2 = ExtendedPublicKey(
  [3, 204, 51, 107, 5, 213, 88, 176, 11, 231, 120, 132, 250, 125, 182, 59, 92, 201, 159, 170, 167, 176, 62, 204, 82, 137, 207, 252, 175, 248, 192, 124, 1],
  [202, 229, 252, 143, 244, 244, 131, 97, 141, 249, 35, 34, 36, 220, 66, 168, 92, 59, 155, 148, 50, 110, 65, 212, 120, 24, 115, 186, 218, 145, 165, 3],
);

// functions hard-coded for the auction backend canister (3gvau-pyaaa-aaaao-qa7kq-cai)
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
  |> p2.deriveChild(_)
  |> _.pubkey_address();
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
