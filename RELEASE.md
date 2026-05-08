# Release Process

Releases follow Semantic Versioning 2.0.0. Before `1.0.0`, the package may
change public APIs between development releases, but every release still needs a
clear changelog, compatibility summary, benchmark summary, and known-limitations
section.

## Version Milestones

- `0.1.0`: binary primitives and package scaffold.
- `0.2.0`: core document, shared type, transactions, arrays/maps/text basics.
- `0.3.0`: full V1/V2 update encoding and sync utilities.
- `0.4.0`: snapshots, relative positions, undo/redo.
- `0.5.0`: attribution, suggestions, subdocuments, XML/tree behavior.
- `0.9.0`: parity tests passing, docs complete, benchmark baselines stable.
- `1.0.0`: full parity verified, no known compatibility gaps, pub.dev polish
  complete, and release checklist signed off.

## Release Checklist

1. Choose the next version according to Semantic Versioning.
2. Update `packages/ycrdt/pubspec.yaml`.
3. Update `packages/ycrdt/CHANGELOG.md` with API changes, compatibility
   summary, benchmark summary, known limitations, and verification evidence.
4. Update `PARITY.md` for implementation, tests, compatibility, docs, and
   benchmark status.
5. Run the credential-free release validation:

   ```sh
   melos run release:validate
   ```

6. Run the full release gate:

   ```sh
   melos run format
   melos run analyze
   melos run validate
   melos run docs
   melos run test
   melos run test:long-random
   melos run examples
   melos run coverage
   melos run benchmark:smoke
   melos run js:smoke
   melos run publish:dry-run
   ```

7. For release candidates, run `melos run benchmark:full` and attach the JSON
   result summary to the release notes.
8. Confirm `dart pub publish --dry-run` has no actionable warnings from
   `packages/ycrdt`.
9. Tag and publish only after the checklist is complete and the package archive
   contents are reviewed.

## Changelog Requirements

Each release entry must include:

- API changes.
- Compatibility summary.
- Benchmark summary.
- Known limitations.
- Verification commands or CI run.

Use neutral package terminology in all release notes, fixtures, and benchmark
names.

## CI Release Validation

CI runs `melos run release:validate` without publish credentials. This validates
release documentation, package metadata, changelog shape, and the absence of
`publish_to: none`. Publishing still requires a maintainer to run the final
authenticated `dart pub publish` command manually.

## Current Readiness Notes

The current readiness audit has no open release blockers. Evidence recorded in
`PARITY.md` includes full tests, long random/fuzz validation, coverage
thresholds, full benchmarks, documentation link validation, compiled JavaScript
smoke checks, release validation, and pub.dev dry-run validation.

Benchmark summary: the full suite covered 24 benchmarks. The slowest cases were
`metadata_id_map_algebra` at 43.64 ms/iteration and
`array_random_insert_delete_nested` at 38.38 ms/iteration, both below the
500 ms full-suite threshold.

Known limitation: the package remains at `0.0.0-dev.1` until the maintainer
chooses the final release version and publishes from a clean tracked git state.
