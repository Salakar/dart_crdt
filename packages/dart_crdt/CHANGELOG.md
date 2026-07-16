# Changelog

## 0.4.0

Corrects three collaboration-critical boundaries: wire `Skip` structs are now
framing metadata rather than persistent state, shared-text relative positions
now convert between Unicode-scalar indexes and UTF-16 wire clocks, and
awareness updates apply atomically with source-safe timeout clocks.

### API Changes

- No public signatures were removed or renamed.
- `DiffAttributionManager.acceptChanges` and `rejectChanges` remain available,
  but now throw `UnsupportedError` before mutation for arbitrary partial
  selections. A range covering all remaining suggestions delegates to the
  corresponding all-change method. This is a fail-closed behavioral correction
  for a path that could create non-contiguous causal history.
- `defaultRelativeContentLength` now reports Unicode scalar values for
  `ContentString` items instead of UTF-16 clock units. This matches
  `SharedType.length`, `insertText`, and `deleteText`.
- `encodeStateAsUpdate` and `encodeStateAsUpdateV2` no longer synthesize wire
  `Skip` structs for causally pending ranges. They emit integrated state and the
  safe pending delete set only.
- Added `validateUpdate` and `validateUpdateV2` for non-mutating validation of
  complete binary frames before using low-level streaming decoder APIs.

### Fixes

- Incoming V1/V2 wire `Skip` structs now advance only the decoder's clock. They
  are never integrated, added to pending block ranges, counted as applied, or
  allowed to advance a receiver's state vector. This prevents a relay snapshot
  from permanently masking the genuine struct that later arrives at a skipped
  clock.
- `encodeStateVectorFromUpdate` and `encodeStateVectorFromUpdateV2` now stop at
  wire-skip, unresolved, or other clock gaps and advertise only a concrete
  prefix proven from clock zero. Target-relative deltas no longer claim an
  unseen prefix.
- Byte-identical causally pending frames are deduplicated per wire version.
  Redelivery no longer grows the retry queue or repeats retry work, while V1
  and V2 frames remain distinct.
- Fixed the deterministic three-replica corruption where a relay received `Y`
  before `X`, inserted concurrent `Z`, and exported a skip-framed update. The
  target now converges from `abc` to `abcZXY` for V1 and V2, including payloads
  emitted by older peers.
- Relative-position creation now maps an in-item scalar offset to its UTF-16
  clock, and resolution maps the clock back with floor semantics inside a
  surrogate pair. Both association directions work across emoji, ZWJ
  sequences, combining marks, flags, and split string items.
- Shared-text deletion and relative positions now reuse one scalar/clock
  conversion helper, preventing the two paths from drifting again.
- Arbitrary partial suggestion decisions now fail before either document is
  mutated. Complete-range decisions delegate to the causal-safe all-change
  paths.
- Rejecting all suggestions now applies the complete post-undo state back to
  the comparison document. Both sides therefore integrate restored ids and
  insertion tombstones before successor or adjacent edits arrive.
- Undo restoration preserves a split item's live right boundary, so rejecting
  an interior deletion restores content before its original right neighbor.
- Awareness updates are now decoded and validated completely before any state
  or event mutation, so malformed provider frames cannot partially commit.
- Timing out a remote awareness client now emits an equal-clock tombstone. The
  tombstone wins over the currently visible state without claiming the source's
  next clock, allowing its first subsequent presence update to recover.
- An echoed timeout tombstone can no longer hide the owning client's local
  awareness state. Its local clock advances beyond accepted self clocks and the
  tombstone so the live payload can be re-fanned immediately.
- `applyUpdate` and `applyUpdateV2` now preflight the complete binary frame
  before opening a live document transaction. A malformed or trailing-byte
  payload can no longer integrate a valid prefix and then report failure.
- Low-level `readUpdate` and `readUpdateV2` now retain the decoder's complete
  original frame for pending retries and retry pending structs/deletes after a
  dependency integrates. V2 no longer mistakes its rest substream for the full
  ten-stream frame. Their existing no-`Doc.update` event behavior is unchanged.

### Compatibility Summary

- The V1/V2 wire layout is unchanged and remains reference-compatible. The
  behavioral change is that received wire `Skip` is interpreted as framing,
  matching the reference semantics, instead of becoming document state.
- Full-state bytes from a document with unresolved pending structs change:
  0.3.x fabricated `Skip` ranges, while 0.4.0 omits those ranges. Providers must
  retain the original update journal until dependencies integrate.
- Update-only state-vector extraction is deliberately conservative: a
  target-relative update cannot establish clocks before its own starting
  clock. Callers with that context should combine the extracted prefix with the
  known target vector.
- Relative-position wire IDs after astral Unicode may differ from 0.3.x because
  0.4.0 anchors the requested scalar rather than treating the scalar index as a
  UTF-16 clock. Existing anchors inside a surrogate pair resolve to the scalar's
  leading boundary for non-negative association and after it for negative
  association.
- Custom relative-position length callbacks retain the legacy one-visible-unit-
  per-clock behavior even when they happen to return the same value as
  `defaultRelativeContentLength`.

### Benchmark Summary

- Public update application performs one isolated structural decode before the
  live decode/integration pass. In the full suite, the V1 and V2 sync workloads
  completed at 8.16 and 8.23 ms/iteration respectively. Scalar/clock conversion
  is linear only within the compound string item being positioned or edited.
- The 24-case full benchmark suite passed. The slowest case was
  `array_random_insert_delete_nested` at 76.40 ms/iteration, below the 500 ms
  release threshold.

### Known Limitations

- `mergeUpdates`, `mergeUpdatesV2`, `diffUpdate`, and `diffUpdateV2` still
  materialize a temporary document and omit causally unresolved structs.
- V1/V2 update-format conversion and update obfuscation have the same pending
  data limitation. Do not use their output as the sole durable copy of a
  causally incomplete update.
- `encodeStateAsUpdate` does not yet merge raw pending update bytes into its
  output. Retain the source update journal until `pendingStructs` is empty.
- Arbitrary partial diff-suggestion acceptance/rejection remains unsupported;
  complete-range and all-change decisions are causal-safe.
- Formatting attributes applied through root or nested `SharedText` APIs are
  not yet stored in the struct store. Plain text syncs, but formatting runs do
  not.
- The default unnamed root (`''`) is not store-backed; use a named root for
  store-backed maps, arrays, and text.

### Verification

- `fvm dart format --output=none --set-exit-if-changed packages/dart_crdt/lib packages/dart_crdt/test`
- `fvm dart analyze`
- Focused Skip, fixed-delta topology, relative-position Unicode, state-update,
  pending-retry, compatibility, and sequential suggestion tests.
- `fvm dart test`
- `fvm dart run tool/run_long_random_tests.dart`
- `fvm dart test --coverage=coverage` plus coverage validation
- `fvm dart run benchmark/benchmark.dart --mode=full`
- `fvm dart run tool/run_js_smoke.dart`
- `fvm dart doc --validate-links`
- `fvm dart run tool/validate_repository.dart`
- `fvm dart run tool/validate_release.dart`
- `fvm dart pub publish --dry-run` from a clean package copy

## 0.3.0

Store-backed maps, arrays, and nested shared types. These now serialize over the
binary wire path (`encodeStateAsUpdate` / `applyUpdate`) with the struct store as
the single source of truth, matching how root text already worked. Previously a
root map or array — and every nested type — encoded to an empty update and never
synced.

### API Changes

- `SharedType.setAttr(key, value, {clock})`: for an integrated root map,
  conflicts now resolve structurally (by item-id order) and the `clock:`
  argument is advisory. Detached maps keep the in-memory clock-based
  last-writer-wins, so their behaviour is unchanged. This is the only
  behavioural change to an existing API.
- `createRelativePositionFromTypeIndex` now accepts nested (non-root) shared
  types; it previously threw `UnsupportedError` for them.
- Added `Doc.itemParentForItemId`, `Doc.sharedTypeForItemId`,
  `Doc.registerSharedTypeForItemId`, `Doc.storeParentForType`, and
  `Doc.liveNestedTypeForItem` for nested-type resolution.
- Added `ItemParent.definingItemId` and `ItemParent.subKeys`.

### Features

- Root maps and arrays are now store-backed and converge over binary updates,
  including concurrent edits, deletes, partitions, duplicate/reordered delivery,
  and the V2 format.
- Nested shared types (a map/array/text inside another container) are now live,
  store-backed, and sync over the wire, including deep nesting and the
  detached-to-integrated flush of a pre-populated type.
- Remote `applyUpdate` now fires `SharedTypeEvent`s on the receiver's observers
  for map and array changes (previously only local mutations emitted events).
- Relative positions anchored to a nested shared type resolve to the live nested
  type with a content-aware index, replacing the previous detached-placeholder
  result at index 0.

### Fixes

- Fixed a latent wire-format bug: the V1 struct writer emitted an item's
  `parentSub` (map key) only inside the no-origin branch, while the decoder
  reads it whenever the `0x20` header bit is set. Map overwrites carry an
  origin, so every superseding write would have dropped its key. The key is now
  written outside the parent block, matching the decoder.

### Compatibility Summary

- Root-only documents remain byte-compatible with 0.2.x: the existing
  serialized compatibility fixtures regenerate byte-for-byte. Maps, arrays, and
  nested types that previously produced empty updates now carry their content.
- The nested-type parent reference uses the standard cross-implementation wire
  format: when an item's parent is a nested type, the parent is encoded as
  `parentInfo(false)` plus the defining item id instead of a root-name string.

### Benchmark Summary

- The smoke suite passes with the store-backed map/array paths exercised:
  `map_set_delete_conflicts` ~1.9 ms/iteration,
  `array_random_insert_delete_nested` ~4.9 ms/iteration, and
  `xml_tree_insert_delete_stringify` ~1.9 ms/iteration, all well within the
  suite threshold. Root text encode/decode hot paths are unchanged.

### Known Limitations

- Nested text formatting attributes are not yet flushed to the store: nested
  text content syncs, but per-run formatting applied to a nested text does not.
- The default unnamed root (`''`) is not store-backed; use a named root for
  store-backed maps, arrays, and text.

### Verification

- `melos run format`
- `melos run analyze`
- `melos run validate`
- `melos run docs`
- `melos run test`
- `melos run examples`
- `melos run coverage` (95.70% overall line coverage; strict files at 100%)
- `melos run benchmark:smoke`
- `melos run js:smoke`
- `melos run release:validate`
- `dart pub publish --dry-run`

## 0.2.2

Bug-fix release: lossless reconstruction of interleaved concurrent inserts from
a single full-state update.

### API Changes

- No public API changes.

### Fixes

- Fixed silent data loss when a single full-state update (`encodeStateAsUpdate`,
  `encodeStateAsUpdateV2`, or a `mergeUpdates` fold) built from two or more
  clients' interleaved concurrent inserts at random interior positions was
  applied to a fresh document. The pending-struct retry loop measured progress
  by the number of pending update *entries*, but a single update whose structs
  carry forward cross-client origin dependencies re-pends itself as the same one
  entry every pass, so the entry count never decreased and the loop stopped
  after a single retry — dropping every struct beyond the second dependency
  layer (e.g. a 160-character co-edited document reconstructed to 22
  characters). The retry now loops until a full pass integrates no further
  structs, so a snapshot of any interleaving converges. The 0.2.1 fix for
  out-of-order delivery of multiple updates is preserved; append-only and
  already-causal updates are unaffected (they integrate on the first pass and
  never re-pend).

### Compatibility Summary

- Wire format, state vectors, and update encoding are unchanged and remain
  byte-compatible with 0.2.0 and 0.2.1. The fix only changes the in-memory retry
  loop that re-applies causally-incomplete updates; no serialized bytes change.
- The behavioural change is strictly corrective: documents that previously
  reconstructed with dropped content now reconstruct in full. No previously
  correct result changes.

### Benchmark Summary

- The common in-order path is unchanged: a causally-complete update leaves
  nothing pending, so the retry loop body never executes and adds no overhead.
- When reconstructing a document from a single update that carries forward
  dependencies (e.g. applying a full-state snapshot of an interleaved concurrent
  history), the retry performs one pass over the pending set per dependency
  layer — previously capped at a single pass. Each struct still integrates at
  most once. This cost is bounded and paid only on that reconstruction path.

### Known Limitations

- Relative positions anchored to a nested (non-root) shared type via a type id
  still resolve against a detached placeholder; nested-type anchors are not yet
  fully supported (root- and item-anchored positions are unaffected).

### Verification

- `melos run format`
- `melos run analyze`
- `melos run test`
- `melos run test:long-random`
- `dart pub publish --dry-run`

## 0.2.1

Bug-fix release: web compilation, full-clear crashes, and out-of-order sync
data loss.

### API Changes

- No public API changes. `StructStore` now retains multiple pending struct
  updates internally (`pendingStructUpdates`) instead of a single slot; the
  existing `pendingStructUpdate` getter is preserved and returns the most
  recent pending update.

### Fixes

- Fixed web (`dart2js`/`dart compile js`) compilation: the content-attribute
  digest no longer uses 64-bit integer literals (`0xffffffffffffffff`,
  `0xcbf29ce484222325`) that cannot be represented exactly in JavaScript. The
  FNV-1a hash is now computed across two 32-bit lanes using only arithmetic
  that is exact on every Dart platform, producing the same 16-hex digest on the
  VM and the web.
- Fixed an `ArgumentError` crash when a single transaction empties a text type
  or array entirely (e.g. select-all then delete). `deleteText`/`delete` no
  longer pre-clamp the search-marker index with `clamp(0, length - 1)`, which
  threw `clamp(0, -1)` once the last item was removed.
- Fixed silent data loss on out-of-order update delivery. When two (or more)
  causally-incomplete updates arrived before their dependencies, the second
  overwrote the first's pending struct bytes, so the first update's content was
  lost forever once dependencies arrived. Pending updates are now retained as a
  list and retried to a fixpoint, so every update converges regardless of
  arrival order.

### Compatibility Summary

- Wire format, state vectors, and update encoding are unchanged and remain
  byte-compatible with 0.2.0. The pending-update fix only affects in-memory
  handling of causally-incomplete updates and changes no serialized bytes.
- The content-attribute `stableHash` digest value changed (it is now web-safe).
  The digest is in-memory only — never serialized or exchanged — so this does
  not affect cross-document sync or persisted data.

### Benchmark Summary

- No benchmark-relevant changes; hot paths (encode/decode, integration) are
  untouched. The pending-update retry now loops to a fixpoint but only over the
  set of causally-incomplete updates, which is empty on the common in-order
  path.

### Known Limitations

- Relative positions anchored to a nested (non-root) shared type via a type id
  still resolve against a detached placeholder; nested-type anchors are not yet
  fully supported (root- and item-anchored positions are unaffected).

### Verification

- `melos run format`
- `melos run analyze`
- `melos run test`
- `melos run js:smoke`
- `dart pub publish --dry-run`

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
