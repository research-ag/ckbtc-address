/// Minimal binding to the IC management canister's `ecdsa_public_key`
/// endpoint, used to fetch a canister's master xpubkey.

import Blob "mo:core/Blob";
import Principal "mo:core/Principal";

module {
  /// Arguments to the management canister's `ecdsa_public_key` method.
  public type ecdsa_public_key_args = {
    canister_id : ?Principal;
    derivation_path : [Blob];
    key_id : { curve : { #secp256k1 }; name : Text };
  };

  /// Result of `ecdsa_public_key`: the 33-byte SEC1-compressed `public_key`
  /// and the 32-byte BIP32 `chain_code`.
  public type ecdsa_public_key_result = {
    public_key : Blob;
    chain_code : Blob;
  };

  /// Typed handle for the IC management canister (`aaaaa-aa`), exposing
  /// only the `ecdsa_public_key` method.
  public let mgmt : actor {
    ecdsa_public_key : ecdsa_public_key_args -> async ecdsa_public_key_result;
  } = actor "aaaaa-aa";
};
