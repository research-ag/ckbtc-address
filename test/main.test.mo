import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
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
type Path = [[Nat8]];
let curve : Curves.Curve = Curves.secp256k1;

class ExtendedPublicKey(
  _key : [Nat8],
  _chaincode : [Nat8],
) {

  public let key = _key;
  public let chaincode = _chaincode;

  // Derive a child public key with path relative to this instance. Returns
  // null if path is #text and cannot be parsed.
  public func derivePath(path : Path) : ?ExtendedPublicKey {
    return do ? {
      // Normalize the given path as an array of indices.
      let pathArray : [[Nat8]] = path;

      var target : ExtendedPublicKey = ExtendedPublicKey(
        key,
        chaincode,
      );

      // Derive the hierarchy of child keys.
      for (childIndex in pathArray.vals()) {
        target := target.deriveChild(childIndex)!;
      };
      target;
    };
  };

  // Derive child at the given index. Valid indices are blobs.
  public func deriveChild(index : [Nat8]) : ?ExtendedPublicKey {

    // Compute HMAC with chaincode as the key and the serialized
    // parentPublicKey (33 bytes) concatenated with the index
    // as its data.
    let hmacData : [var Nat8] = Array.init<Nat8>(33 + index.size(), 0x00);
    Common.copy(hmacData, 0, key, 0, 33);
    Common.copy(hmacData, 33, index, 0, index.size());
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
      return null;
    };

    switch (Jacobi.fromBytes(key, curve)) {
      case (null) {
        return null;
      };
      case (?parsedKey) {
        // Derive the child public key.
        switch (Jacobi.add(Jacobi.mulBase(multiplicand, curve), parsedKey)) {
          case (#infinity(_)) {
            return null;
          };
          case (childPublicKey) {
            return ?ExtendedPublicKey(
              Jacobi.toBytes(childPublicKey, true),
              right,
            );
          };
        };
      };
    };
  };
};

// Now we can use the modified version

// Get the ckBTC minter's deposit address for account
func get_deposit_addr(account : { owner : Principal; subaccount : ?Blob}) : Text {
  let p = ExtendedPublicKey(minter_pubkey, minter_chaincode);
  let ?k = p.derivePath([
    [1],
    Blob.toArray(Principal.toBlob(account.owner)),
    switch (account.subaccount) {
      case (?s) Blob.toArray(s);
      case (_) [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    }
  ]) else Debug.trap("derivation failed");
  switch (Segwit.encode("bc", { version = 0; program = Hash.hash160(k.key)})) {
    case (#ok addr) return addr;
    case (#err e) Debug.trap(e);
  };
};

// This returns bc1q7ecd9c4vh8efh8v9pyz5jzz2glr22wxvxav7d3 
// It can be reproduced with https://play.motoko.org/?tag=1890044230
// by calling get_btc_address() with the same arguments 
let addr = get_deposit_addr({ 
  owner = Principal.fromText("2vxsx-fae");
  subaccount = null
});
Debug.print(debug_show addr); 
