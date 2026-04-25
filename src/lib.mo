/// BTC deposit address generator for the ckBTC minter.
///
/// This module reproduces the Bitcoin address derivation algorithm used by
/// the ckBTC minter on the Internet Computer. Given the minter's root
/// extended public key (xpubkey), it derives the unique P2WPKH (SegWit, mainnet
/// `bc1...`) Bitcoin deposit address that the minter would assign to any
/// ICRC-1 account `(owner, subaccount)`. Any BTC sent to that address is
/// converted to ckBTC and credited to the corresponding ICRC-1 account.
///
/// The implementation is a stripped-down BIP32 derivation that operates
/// directly on byte-string indices (rather than the standard 32-bit indices),
/// matching the ckBTC minter's derivation scheme:
///
/// `xpub / "\01" / owner-principal-bytes / subaccount-bytes`
///
/// where `subaccount-bytes` defaults to the 32 zero bytes when the ICRC-1
/// subaccount is `null`.
///
/// The minter's root xpubkey can either be hard-coded by the caller or
/// fetched at runtime from the IC's threshold-ECDSA API via
/// `fetchEcdsaKey`.
///
/// ```motoko name=import
/// import CkBtcAddress "mo:ckbtc-address";
/// import Principal "mo:core/Principal";
/// ```
///
/// Example — derive a single deposit address for a hard-coded mainnet
/// ckBTC minter xpubkey:
///
/// ```motoko include=import
/// let minter = CkBtcAddress.Minter({
///   public_key = "\02\22\04\7A\81\D4\F8\A0\67\03\1C\89\27\3D\24\1B\79\A5\A0\07\C0\4D\FA\F3\6D\07\96\3D\B0\B9\90\97\EB";
///   chain_code = "\82\1A\EB\B6\43\BD\97\D3\19\D2\FD\0B\2E\48\3D\4E\7D\E2\EA\90\39\FF\67\56\8B\69\3E\6A\BC\14\A0\3B";
/// });
/// let addr : Text = minter.deposit_addr({
///   owner = Principal.fromText("aaaaa-aa");
///   subaccount = null;
/// });
/// ```

import Blob "mo:core/Blob";
import Principal "mo:core/Principal";
import Runtime "mo:core/Runtime";

import Bip32 "internal/bip32";
import IC "internal/ic";

module {
  /// An extended public key (xpubkey) as returned by the IC management
  /// canister's `ecdsa_public_key` endpoint.
  ///
  /// `public_key` is the 33-byte SEC1-compressed secp256k1 point and
  /// `chain_code` is the 32-byte BIP32 chain code. Together they form the
  /// root of a BIP32 derivation tree.
  public type XPubKey = {
    public_key : Blob;
    chain_code : Blob;
  };

  /// An ICRC-1 account.
  ///
  /// `owner` is the account owner's principal. `subaccount`, when present,
  /// must be a 32-byte blob; `null` is treated as the all-zero default
  /// subaccount (the same convention used by ICRC-1 itself and by the ckBTC
  /// minter when assigning deposit addresses).
  public type Account = {
    owner : Principal;
    subaccount : ?Blob;
  };

  /// A ckBTC deposit-address derivator initialized from the minter's root
  /// extended public key.
  ///
  /// Construction performs one BIP32 child derivation (with the constant
  /// single-byte index `"\01"`) to obtain the ckBTC minter's account-derivation
  /// subtree. After that, every call to `deposit_addr` performs two further
  /// child derivations (one for the owner principal, one for the subaccount)
  /// and encodes the resulting public key as a mainnet P2WPKH SegWit address
  /// (`bc1...`).
  ///
  /// `key` must be the master xpubkey of the ckBTC minter canister you want
  /// to mirror (e.g. mainnet ckBTC, testnet ckBTC, or a custom deployment).
  /// It can be obtained via `fetchEcdsaKey` or hard-coded.
  ///
  /// Traps if `key.public_key` is not a valid SEC1-compressed secp256k1 point
  /// (33 bytes encoding a point on the curve).
  public class Minter(key : XPubKey) {
    let pk = Bip32.ExtendedPublicKey(key.public_key.toArray(), key.chain_code.toArray()).deriveChild("\01");

    /// Returns the mainnet P2WPKH Bitcoin deposit address (a `bc1...`
    /// Bech32 string) that the ckBTC minter assigns to the given ICRC-1
    /// `account`.
    ///
    /// A `null` subaccount is treated as the 32-byte all-zero default
    /// subaccount, matching ICRC-1 and ckBTC-minter conventions.
    ///
    /// ```motoko include=import
    /// let addr = minter.deposit_addr({
    ///   owner = Principal.fromText("aaaaa-aa");
    ///   subaccount = null;
    /// });
    /// ```
    ///
    /// Traps if `account.subaccount` is `?b` with `b.size() != 32`.
    public func deposit_addr(account : Account) : Text {
      let sub = switch (account.subaccount) {
        case (null) "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob;
        case (?b) {
          if (b.size() != 32) Runtime.trap("ckbtc-address: subaccount must be exactly 32 bytes");
          b;
        };
      };
      [account.owner.toBlob(), sub]
      |> pk.derivePath(_)
      |> _.pubkey_address();
    };

    /// Returns a per-owner derivation function that maps subaccounts to
    /// deposit addresses.
    ///
    /// This is an optimization for the common case of one fixed owner (e.g.
    /// a service canister) deriving deposit addresses for many users
    /// distinguished only by subaccount: the (relatively expensive) BIP32
    /// child derivation for the owner principal is performed once, when
    /// `deposit_addr_func` is called, and the returned closure only performs
    /// the cheaper subaccount derivation per call.
    ///
    /// The returned function follows the same conventions as `deposit_addr`:
    /// `null` is treated as the 32-byte all-zero default subaccount, and the
    /// result is a mainnet P2WPKH `bc1...` address.
    ///
    /// ```motoko include=import
    /// let derive = minter.deposit_addr_func(Principal.fromText("aaaaa-aa"));
    /// let addr1 = derive(null);
    /// let addr2 = derive(?("\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\01" : Blob));
    /// ```
    ///
    /// The returned closure traps if it is called with `?b` where
    /// `b.size() != 32`.
    public func deposit_addr_func(owner : Principal) : ?Blob -> Text {
      let p1 = pk.deriveChild(owner.toBlob());
      func(subaccount : ?Blob) : Text {
        let sub = switch (subaccount) {
          case (null) "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00" : Blob;
          case (?b) {
            if (b.size() != 32) Runtime.trap("ckbtc-address: subaccount must be exactly 32 bytes");
            b;
          };
        };
        p1.deriveChild(sub).pubkey_address();
      };
    };
  };

  /// Fetches the master ECDSA extended public key of the canister identified
  /// by `p` from the IC management canister.
  ///
  /// Calls the management canister's `ecdsa_public_key` endpoint with an
  /// empty derivation path and `key_id = { curve = #secp256k1; name = "key_1" }`
  /// (the production ECDSA key on the IC mainnet). For the ckBTC minter
  /// canister this returns the same root xpubkey that should be passed to
  /// the `Minter` constructor.
  ///
  /// ```motoko include=import
  /// let xpub = await* CkBtcAddress.fetchEcdsaKey(Principal.fromText("mqygn-kiaaa-aaaar-qaadq-cai"));
  /// let minter = CkBtcAddress.Minter(xpub);
  /// ```
  ///
  /// This function performs an inter-canister call to the management
  /// canister. The `ecdsa_public_key` endpoint itself is free (no
  /// per-call cycle fee); only the small base inter-canister-call fee
  /// applies, which is paid out of the calling canister's cycle balance.
  ///
  /// The call does not trap on rejection; instead the rejection is
  /// surfaced as an async error that propagates out of the `await`,
  /// where the caller can handle it with `try`/`catch`. The two main
  /// rejection causes are:
  ///
  /// - the named ECDSA key does not exist on the subnet routing the
  ///   call (e.g. `"key_1"` is the production key on IC mainnet, but
  ///   local replicas typically only expose `"dfx_test_key"` and
  ///   testnets expose `"test_key_1"`);
  /// - the calling canister has too few cycles to cover the
  ///   inter-canister-call base fee (in this case the system may also
  ///   freeze or trap the canister depending on its freezing
  ///   threshold).
  ///
  /// For non-mainnet environments, call the management canister
  /// directly with the appropriate `key_id.name` instead of using this
  /// helper.
  public func fetchEcdsaKey(p : Principal) : async* XPubKey {
    await IC.mgmt.ecdsa_public_key({
      canister_id = ?p;
      derivation_path = [];
      key_id = { curve = #secp256k1; name = "key_1" };
    });
  };

};
