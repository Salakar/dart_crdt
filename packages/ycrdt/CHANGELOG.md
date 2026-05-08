# Changelog

## 0.0.0-dev.1

Initial development release with package metadata, documentation, tests,
benchmarks, and CI scaffolding.

### API Changes

- Introduced the initial package API surface for development validation.

### Compatibility Summary

- Added neutral compatibility fixtures and binary update validation scaffolding.
- 1.0 readiness audit passed serialized fixture round trips, long random
  convergence, compiled JavaScript smoke checks, and the forbidden-reference
  package policy scan.

### Benchmark Summary

- Added benchmark smoke and full-suite entrypoints with baseline thresholds.
- Full readiness benchmark run covered 24 benchmarks. Slowest cases were
  `metadata_id_map_algebra` at 43.64 ms/iteration and
  `array_random_insert_delete_nested` at 38.38 ms/iteration, both below the
  500 ms full-suite threshold.

### Known Limitations

- This is a development release and is not a stable `1.0.0` API contract.
- No readiness blockers are open from the current audit, but publishing still
  requires a maintainer-selected final version and a clean tracked git state.

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
