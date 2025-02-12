import Blob "mo:base/Blob";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Bip32 "bip32";
import IC "ic";

module {
  public type XPubKey = {
    public_key : Blob;
    chain_code : Blob;
  };

  // ICRC-1 account
  public type Account = {
    owner : Principal;
    subaccount : ?Blob;
  };

  // Initialize with the minter's xpubkey 
  // The application can either hard-code this key or can use the helper function `fetchEcdsaKey` below
  public class Minter(key : XPubKey) {
    let pk = Bip32.ExtendedPublicKey(Blob.toArray(key.public_key), Blob.toArray(key.chain_code)).deriveChild("\01");

    // Calculate BTC deposit address for ICRC-1 account
    public func deposit_addr(account : Account) : Text {
      [
        Principal.toBlob(account.owner),
        Option.get(account.subaccount, "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob),
      ]
      |> pk.derivePath(_)
      |> _.pubkey_address();
    };
  };

  // Fetch a canister's master ECDSA xpubkey
  public func fetchEcdsaKey(p : Principal) : async* XPubKey {
    await IC.mgmt.ecdsa_public_key({
      canister_id = ?p;
      derivation_path = [];
      key_id = { curve = #secp256k1; name = "key_1" };
    });
  };

};
