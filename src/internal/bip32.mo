/// Modified BIP32 public-key derivation used internally by the ckBTC
/// address module.
///
/// Adapted from `motoko-bitcoin`'s `Bip32.ExtendedPublicKey` with two
/// changes: unused fields (`depth`, `index`, `parentPublicKey`) are
/// removed, and derivation indices are arbitrary `Blob`s instead of
/// 32-bit integers — matching the ckBTC minter's derivation scheme.

import Array "mo:core/Array";
import Blob "mo:core/Blob";
import Nat8 "mo:core/Nat8";
import Runtime "mo:core/Runtime";

import Common "mo:bitcoin/Common";
import Curves "mo:bitcoin/ec/Curves";
import Hash "mo:bitcoin/Hash";
import Hmac "mo:bitcoin/Hmac";
import Jacobi "mo:bitcoin/ec/Jacobi";
import Segwit "mo:bitcoin/Segwit";

module {

  /// A BIP32 derivation path: a sequence of arbitrary-length byte indices.
  public type Path = [Blob];
  let curve : Curves.Curve = Curves.secp256k1;

  /// A BIP32 extended public key.
  public type ExtendedPublicKey = {
    key : [Nat8];
    chaincode : [Nat8];
  };

  /// Creates a new `ExtendedPublicKey` from a 33-byte SEC1-compressed
  /// public key and a 32-byte chain code.
  public func new(_key : [Nat8], _chaincode : [Nat8]) : ExtendedPublicKey {
    { key = _key; chaincode = _chaincode };
  };

  /// Derive the child key obtained by applying every index in `path` in
  /// order. Equivalent to repeated `deriveChild` calls.
  public func derivePath(self : ExtendedPublicKey, path : Path) : ExtendedPublicKey {
    var target : ExtendedPublicKey = self;

    // Derive the hierarchy of child keys.
    for (childIndex in path.vals()) {
      target := deriveChild(target, childIndex);
    };
    target;
  };

  /// Derive a single child key at the given byte-string `index`. Traps
  /// (with probability < 2^-127) if the resulting scalar is invalid or
  /// the resulting point is the point at infinity, or if `key` is not a
  /// valid secp256k1 point.
  public func deriveChild(self : ExtendedPublicKey, index : Blob) : ExtendedPublicKey {

    // Compute HMAC with chaincode as the key and the serialized
    // parentPublicKey (33 bytes) concatenated with the index
    // as its data.
    let hmacSha512 : Hmac.Hmac = Hmac.sha512(self.chaincode);
    hmacSha512.writeArray(self.key);
    hmacSha512.writeArray(index.toArray());
    let fullNode : [Nat8] = hmacSha512.sum().toArray();

    // Split HMAC output into two 32-byte sequences.
    let left = fullNode.sliceToArray(0, 32);
    let right = fullNode.sliceToArray(32, 64);

    // Parse the left 32-bytes as an integer in the domain parameters of
    // secp2secp256k1 curve.
    let multiplicand : Nat = Common.readBE256(left, 0);
    if (multiplicand >= curve.r) {
      // This has probability lower than 1 in 2^127.
      Runtime.trap("derivation failed");
    };

    switch (Jacobi.fromBytes(self.key, curve)) {
      case (null) Runtime.trap("derivation failed");
      case (?parsedKey) {
        // Derive the child public key.
        switch (Jacobi.add(Jacobi.mulBase(multiplicand, curve), parsedKey)) {
          case (#infinity(_)) Runtime.trap("derivation failed");
          case (childPublicKey) {
            return {
              key = Jacobi.toBytes(childPublicKey, true);
              chaincode = right;
            };
          };
        };
      };
    };
  };

  /// Encode `key` as a mainnet P2WPKH (SegWit v0) Bitcoin address with
  /// HRP `"bc"` (Bech32).
  public func pubkey_address(self : ExtendedPublicKey) : Text {
    switch (Segwit.encode("bc", { version = 0; program = Hash.hash160(self.key) })) {
      case (#ok addr) return addr;
      case (#err e) Runtime.trap(e);
    };
  };
};
