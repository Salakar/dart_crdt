# Changelog

## 0.2.0

Adds the first production-oriented sync path for high-level shared text edits
and rounds out several public convenience APIs.

### API Changes

- Added provider-neutral `Awareness` presence state with binary update
  encoding, application, and offline removal helpers.
- Added typed root helpers: `getMap`, `getArray`, `getText`, and
  `getXmlFragment`.
- Added update-only state-vector helpers for V1 and V2 updates.
- Added `EventHandler.once`.
- Added XML child insertion after a reference node.

### Fixes

- Fixed root `SharedText.insertText` and `deleteText` so high-level text edits
  produce CRDT structs, encode into V1/V2 state updates, apply on remote
  documents, and converge for concurrent inserts.
- Fixed update integration to clean item boundaries for middle text inserts.
- Updated README and examples to use the public shared text API instead of raw
  `Item(ContentString(...))` setup.

### Verification

- `melos run analyze --no-select`
- `melos run test --no-select`
- `dart run tool/validate_repository.dart`
- `dart pub publish --dry-run`

## 0.1.0

Initial public release with package metadata, documentation, tests,
benchmarks, CI scaffolding, and the core Dart CRDT API surface.

### API Changes

- Introduced the initial package API surface for local-first collaborative
  documents, shared types, binary updates, rich text, snapshots, relative
  positions, undo/redo, attribution metadata, and validation fixtures.

### Compatibility Summary

- Added neutral compatibility fixtures and binary update validation coverage.
- Release validation passed serialized fixture round trips, long random
  convergence, compiled web smoke checks, and package policy scans.

### Benchmark Summary

- Added benchmark smoke and full-suite entrypoints with baseline thresholds.
- Full benchmark run covered 24 benchmarks. Slowest cases were
  `metadata_id_map_algebra` at 74.75 ms/iteration and
  `array_random_insert_delete_nested` at 63.93 ms/iteration, both below the
  500 ms full-suite threshold.

### Known Limitations

- This is a pre-1.0 release and is not a stable `1.0.0` API contract.
- No release blockers are open from the current audit.

### Verification

- `melos run test`
- `melos run test:long-random`
- `melos run coverage` at 95.21% overall with strict codec/metadata/update
  algebra thresholds passing.
- `melos run benchmark:full`
- `melos run docs`
- `melos run js:smoke`
- `melos run release:validate`
- `dart pub publish --dry-run` with 0 warnings.
