module {
  public type ecdsa_public_key_args = {
    canister_id : ?Principal;
    derivation_path : [Blob];
    key_id : { curve : { #secp256k1 }; name : Text };
  };

  public type ecdsa_public_key_result = {
    public_key : Blob;
    chain_code : Blob;
  };

  public let mgmt : actor {
    ecdsa_public_key : ecdsa_public_key_args -> async ecdsa_public_key_result;
  } = actor "aaaaa-aa";
}
