# ckbtc-address changelog

## 0.0.3

- Converted API from class-based to static module (record type).
- Bumped `core` dependency from `2.5.0` to `2.6.2` and `bitcoin` from `0.2.0` to `0.2.1`.
- Added `[requirements] moc = "1.4.0"` (required by `core` 2.6).
- Compiles warning-free with moc 2.0.0.

## 0.0.2

- Migrated from `mo:base` to `mo:core` (requires `moc` 1.0.0 or higher).
- Bumped `motoko-bitcoin` dependency to 0.2.0.
- Moved `bip32.mo` and `ic.mo` into `src/internal/`.
- `deposit_addr` and the closure returned by `deposit_addr_func` now trap
  if a non-null subaccount is not exactly 32 bytes long.
- Added doc strings for the public API.

## 0.0.1

- Initial version
