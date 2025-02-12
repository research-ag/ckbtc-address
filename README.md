# BTC Deposit Address Generator for ckBTC Minter

This Motoko module provides an implementation of a Bitcoin address derivation algorithm for depositing BTC to the ckBTC minter on the Internet Computer.

## Overview

The module derives SegWit (P2WPKH) Bitcoin addresses for depositing BTC into a ckBTC minter using an extended public key (xpub). It follows the BIP32 key derivation standard and uses the Internet Computer's ECDSA API to fetch the canister's master key.

### Features
- BIP32 hierarchical deterministic (HD) key derivation
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

### Deriving a BTC Deposit Address

For a given ICRC-1 account:

```motoko
let account = {
    owner = Principal.fromText("<owner-principal>");
    subaccount = null;  // Optional subaccount
};

let depositAddress = minter.deposit_addr(account);
```

Alternatively, using a function-based approach:

```motoko
let depositAddressFunc = minter.deposit_addr_func(Principal.fromText("<owner-principal>"));
let btcAddress = depositAddressFunc(null);  // Passing optional subaccount
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
- Modifies `ExtendedPublicKey` from `motoko-bitcoin` by removing unnecessary fields.
- Provides functions for deriving child keys and computing Bitcoin addresses.

### `ic.mo`
- Defines the interface for interacting with the Internet Computer management canister.
- Provides access to the ECDSA public key API.

### `lib.mo`
- Implements the `Minter` class.
- Computes deposit addresses based on the derived keys.
- Provides a helper function to fetch the canister's xpub key.

## License

This project is licensed under the MIT License.

