# Contributing

This repository is a Melos workspace for the `ycrdt` Dart package. Keep changes
small, tested, and package-native.

## Setup

Install the Dart SDK, then activate Melos and bootstrap the workspace:

```sh
dart pub global activate melos
melos bootstrap
```

Use the SDK constraint in `packages/ycrdt/pubspec.yaml` as the minimum supported
Dart version for local development and CI.

## Required Checks

Run the relevant focused tests while developing, then run the full gate before a
pull request:

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
melos run release:validate
melos run publish:dry-run
```

Use `melos run benchmark:full` for changes that affect binary encoding,
transactions, shared-type behavior, update algebra, snapshots, relative
positions, undo/redo, attribution, or garbage collection.

## Tests And Fixtures

Add tests with every behavior change:

- Unit tests belong in `packages/ycrdt/test/unit/`.
- Integration and convergence tests belong in `packages/ycrdt/test/integration/`.
- Shared helpers belong in `packages/ycrdt/test/helpers/`.
- Test data belongs in `packages/ycrdt/test/fixtures/`.
- Compatibility fixtures belong in `packages/ycrdt/test/fixtures/compat/`.

Keep each test file focused on one logical unit. If a test file grows large,
split it by feature or scenario before adding more cases.

For compatibility fixtures, keep fixture names, descriptions, JSON keys, and
test names neutral. Do not copy reference-project branding into package code,
tests, docs, benchmark names, CI, or generated fixtures. Use deterministic
serialized payloads, expected state-vector summaries, and round-trip assertions
so the fixture can prove behavior without relying on prose.

## Documentation

Public APIs must have dartdoc comments. Add runnable examples for high-value
APIs and warnings for advanced binary/storage APIs that most application code
should not use directly. When public examples change, update README snippets,
`example/`, and the example output tests.

## Benchmarks

Performance-sensitive changes need benchmark coverage or an explicit rationale
in the pull request. Include baseline updates only when the implementation
change justifies the new numbers, and mention the workload, platform, and
command used to produce them.

## Commit And PR Expectations

Use concise conventional commit subjects when practical, for example
`feat(sync): merge pending updates`. Pull requests should include:

- A short summary of the behavioral change.
- The exact checks run locally.
- Compatibility fixture impact, if any.
- Benchmark impact or rationale, if performance-sensitive.
- Documentation and example updates, if public APIs changed.
- Any known limitations or follow-up issues.

Do not include unrelated formatting, generated files, or cleanup in a feature
PR. If you discover unrelated issues, open or reference an issue rather than
fixing them opportunistically.

## Release Checklist

Release candidates must follow `RELEASE.md`. At minimum, update the package
version, changelog, parity status, compatibility notes, benchmark summary, known
limitations, and verification evidence before running `melos run
release:validate` and `melos run publish:dry-run`.

## Security Handling

Report vulnerabilities privately using GitHub Security Advisories:
<https://github.com/mikediarmid/ycrdt/security/advisories/new>.

Do not open public issues for suspected vulnerabilities. Maintainers will
confirm the report, coordinate a fix, prepare tests, publish a patched release
when needed, and disclose publicly after a mitigation is available.
