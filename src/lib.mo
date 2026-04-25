import Blob "mo:core/Blob";
import Option "mo:core/Option";
import Principal "mo:core/Principal";

import Bip32 "internal/bip32";
import IC "internal/ic";

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
    let pk = Bip32.ExtendedPublicKey(key.public_key.toArray(), key.chain_code.toArray()).deriveChild("\01");

    // Calculate BTC deposit address for ICRC-1 account
    public func deposit_addr(account : Account) : Text {
      [
        account.owner.toBlob(),
        Option.get(account.subaccount, "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob),
      ]
      |> pk.derivePath(_)
      |> _.pubkey_address();
    };

    public func deposit_addr_func(owner : Principal) : ?Blob -> Text {
      let p1 = pk.deriveChild(owner.toBlob());
      func(subaccount : ?Blob) : Text {
        Option.get(subaccount, "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob)
        |> p1.deriveChild(_)
        |> _.pubkey_address();
      };
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
