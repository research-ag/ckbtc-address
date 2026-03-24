import Blob "mo:core/Blob";
import Option "mo:core/Option";
import Principal "mo:core/Principal";
import Bip32 "bip32";
import IC "ic";

module {
  public type XPubKey = {
    publicKey : Blob;
    chainCode : Blob;
  };

  // ICRC-1 account
  public type Account = {
    owner : Principal;
    subaccount : ?Blob;
  };

  // Initialize with the minter's xpubkey
  // The application can either hard-code this key or can use the helper function `fetchEcdsaKey` below
  public class Minter(key : XPubKey) {
    let pk = Bip32.ExtendedPublicKey(Blob.toArray(key.publicKey), Blob.toArray(key.chainCode)).deriveChild("\01");

    // Calculate BTC deposit address for ICRC-1 account (camelCase preferred)
    public func depositAddr(account : Account) : Text {
      [
        Principal.toBlob(account.owner),
        Option.get(account.subaccount, "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob),
      ]
      |> pk.derivePath(_)
      |> _.pubkeyAddress();
    };

    // Backward-compatible snake_case alias
    public func deposit_addr(account : Account) : Text { depositAddr(account) };

    public func depositAddrFunc(owner : Principal) : ?Blob -> Text {
      let p1 = pk.deriveChild(Principal.toBlob(owner));
      func (subaccount : ?Blob) : Text {
        Option.get(subaccount, "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob)
        |> p1.deriveChild(_)
        |> _.pubkeyAddress();
      };
    };

    // Backward-compatible snake_case alias
    public func deposit_addr_func(owner : Principal) : ?Blob -> Text { depositAddrFunc(owner) };
  };

  // Fetch a canister's master ECDSA xpubkey
  public func fetchEcdsaKey(p : Principal) : async* XPubKey {
    let res = await IC.mgmt.ecdsa_public_key({
      canister_id = ?p;
      derivation_path = [];
      key_id = { curve = #secp256k1; name = "key_1" };
    });
    { publicKey = res.public_key; chainCode = res.chain_code };
  };

};
