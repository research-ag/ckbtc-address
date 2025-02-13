[![mops](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/mops/ckbtc-address)](https://mops.one/ckbtc-address)
[![documentation](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/documentation/ckbtc-address)](https://mops.one/ckbtc-address/docs)

# BTC Deposit Address Generator for ckBTC Minter

This Motoko module provides an implementation of the Bitcoin address derivation algorithm 
used by the ckBTC minter
for determining any user's BTC deposit address.

## Overview

When converting BTC to ckBTC the user can choose any ICRC-1 account (owner and subaccount) that is to be credited with the newly minted ckBTC.
The ckBTC minter derives for each such ICRC-1 account a unique Bitcoin deposit address.
Any BTC deposit made to this Bitcoin address will then be converted to ckBTC and credited to the ICRC-1 account.

The derivation process uses the minter's root extended public key (xpubkey),
a specific derivation path which includes the owner and subaccount of the ICRC-1 account,
and derives a P2WPKH (Segwit) Bitcoin address.

The module implements this derivation algorithm so that any Motoko canister can calculate deposit addresses internally
without having to call the ckBTC minter.
The underlying derivation is based on the same key derivation function that is used by BIP32.

The algorithm is initialized with the minter's root xpubkey.
Therefore, it can also be used for any variant of the ckBTC minter as well, 
for example, for the ckBTC minter for testnet Bitcoin.
The module also provides a helper function to fetch the root xpubkey of any canister from the IC's ECDSA API. 
So the application code has the choice to either hard-code the minter's root xpubkey or to fetch it dynamically with the helper function.

The typical application is a canister service that wants to allow it's users to deposit Bitcoin to the service.
The service will derive a Bitcoin deposit address for each of its users with this module.
The ICRC-1 account used in the derivation has the service as the owner and the user's principal is embedded into the subaccount.
Any BTC deposited to the derived address will then be credited to the service,
and the service can identify which user made the deposit by the subaccount. 

### Features

- Modified BIP32 hierarchical deterministic (HD) key derivation
- SegWit (P2WPKH) Bitcoin address generation
- Fetching canister's ECDSA xpub key
- Computing deposit addresses for ICRC-1 accounts

## Installation

You can install the module using [Mops](https://mops.one/), the package manager for Motoko:

```sh
mops install ckbtc-address
```

## Usage

### Importing the Module

```motoko
import CkBtcAddress "mo:ckbtc-address";
```

### Fetching the xpub Key

To fetch the ECDSA extended public key from a canister:

```motoko
let xpub : CkBtcAddress.XPubKey = await* CkBtcAddress.fetchEcdsaKey(<principal>);
```

### Creating a Minter Instance

```motoko
let minter = CkBtcAddress.Minter(xpub);
```

The ckBTC minter's xpubkey is:

```motoko
let minter = CkBTCAddress.Minter({
  public_key = "\02\22\04\7A\81\D4\F8\A0\67\03\1C\89\27\3D\24\1B\79\A5\A0\07\C0\4D\FA\F3\6D\07\96\3D\B0\B9\90\97\EB";
  chain_code = "\82\1A\EB\B6\43\BD\97\D3\19\D2\FD\0B\2E\48\3D\4E\7D\E2\EA\90\39\FF\67\56\8B\69\3E\6A\BC\14\A0\3B";
});
```

### Deriving a BTC Deposit Address

For a given ICRC-1 account:

```motoko
let account = {
    owner = Principal.fromText("<owner-principal>");
    subaccount = null;  // Optional subaccount
};

let depositAddress = minter.deposit_addr(account);
```

### Deriving BTC deposit addresses for many users of a service

Say a canister service has canister id `<canister id>`.  
Then we define the following derivation function once:

```motoko
let service_principal = Principal.fromText(<canister id>);
let depositAddressFunc = minter.deposit_addr_func(service_principal);
```

Now say the service has a function `embed : Principal -> Blob`
which embeds a user principal into a 32 byte subaccount.
Then we derive the user's deposit address as follows:

```motoko
let btcAddress = depositAddressFunc(?embed(<user principal>));
```

## Testing & Benchmarking

Run the module tests:

```sh
mops test
```

Run benchmarks:

```sh
mops bench
```

## Module Structure

The package consists of three Motoko files:

### `bip32.mo`
- Implements BIP32 key derivation.
- Modifies `ExtendedPublicKey` from `motoko-bitcoin` by
    - removing unnecessary fields,
    - generalizing the derivation index from Nat32 to Blob.
- Provides function for computing Bitcoin addresses.

### `ic.mo`
- Defines the interface for interacting with the Internet Computer management canister.
- Provides access to the ECDSA public key API.

### `lib.mo`
- Implements the `Minter` class.
- Computes deposit addresses based on the same derivation path that is used in the ckBTC minter.
- Provides a helper function to fetch the canister's xpub key.

## License

This project is licensed under the MIT License.
