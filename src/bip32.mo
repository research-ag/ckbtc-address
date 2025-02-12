import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";

import Common "mo:bitcoin/Common";
import Segwit "mo:bitcoin/Segwit";
import Hmac "mo:bitcoin/Hmac";
import Hash "mo:bitcoin/Hash";
import Curves "mo:bitcoin/ec/Curves";
import Jacobi "mo:bitcoin/ec/Jacobi";

// The module contains a modified version of the class ExtendedPublicKey
// from https://github.com/dfinity/motoko-bitcoin/blob/main/src/Bip32.mo
// The modifications are:
// - remove unneeded fields depth, index, parentPublicKey
// - generalize path from [Nat32] to [Blob]
module {

  public type Path = [Blob];
  let curve : Curves.Curve = Curves.secp256k1;

  public class ExtendedPublicKey(
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

    // convert pubkey to a P2WPKh (Segwit) Bitcoin address
    public func pubkey_address() : Text {
      switch (Segwit.encode("bc", { version = 0; program = Hash.hash160(key) })) {
        case (#ok addr) return addr;
        case (#err e) Debug.trap(e);
      };
    };
  };
};
