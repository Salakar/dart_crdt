<p align="center">
<img src="assets/logo.png" alt="dart_crdt logo" width="160" height="160"/>
</p>
<h1 align="center">dart_crdt</h1>
<hr>

<p align="center">
<a href="COVERAGE.md">Coverage: 95.21%</a>
</p>

## Overview

`dart_crdt` is a pure Dart CRDT package for local-first collaborative data
structures. It is designed for Dart VM, Flutter, and web runtimes, with
deterministic binary update encoding and package-native APIs for documents,
shared types, rich text, undo/redo, snapshots, and relative positions.

## Quick Example

```dart
import 'package:dart_crdt/dart_crdt.dart';

void main() {
  final doc = Doc();
  final text = doc.get('body', SharedTypeKind.text);

  text.insertText(0, 'Hello, local-first Dart.');

  print(text.toPlainText());
}
```

## Supported Features

| Area | Support |
| --- | --- |
| Documents | Client IDs, transactions, roots, observers, lifecycle events, and subdocuments. |
| Shared types | Arrays, maps, text, XML-like trees, nested types, embeds, and attributes. |
| Sync | Deterministic V1/V2 updates, state vectors, merge/diff helpers, and update application. |
| Editing | Rich-text deltas, snapshots, relative positions, undo/redo, and attribution metadata. |
| Verification | Unit, integration, fixture, fuzz, benchmark, coverage, and compiled web checks. |

## Packages

This repository is a Melos workspace.

| Path | Purpose |
| --- | --- |
| `packages/dart_crdt` | The publishable `dart_crdt` package. |
| `packages/dart_crdt/benchmark` | Benchmark harnesses and regression thresholds. |
| `tool/` | Repository validation and coverage tools. |

For package usage, start with [packages/dart_crdt/README.md](packages/dart_crdt/README.md).

## Development

```sh
dart pub global activate melos
melos bootstrap
melos run format
melos run analyze
melos run test
melos run benchmark:smoke
melos run js:smoke
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, testing, coverage,
benchmarking, and pull request expectations.

## Benchmarks

| Field | Value |
| --- | --- |
| Mode | full |
| Generated | 2026-05-08T01:46:16.733514Z |
| Runtime | Dart 3.10.0-247.0.dev, macos, 8 processors |
| Benchmarks | 24 |
| Threshold | 500.00 ms/iteration max per benchmark |

| Slowest benchmark | Workload | Iterations | ms/iteration |
| --- | --- | ---: | ---: |
| `metadata_id_map_algebra` | Run IdMap merge, diff, intersection, and filter workloads. | 120 | 74.75 |
| `array_random_insert_delete_nested` | Run deterministic array insert/delete with nested types. | 120 | 63.93 |
| `sync_v2_encode_apply_merge_diff` | Encode, apply, merge, and diff V2 state updates. | 120 | 12.79 |
| `xml_tree_insert_delete_stringify` | Build, edit, walk, and stringify an XML tree. | 120 | 12.61 |
| `sync_update_format_convert` | Convert V1 updates to V2 and back to V1. | 120 | 12.59 |
| `sync_v1_encode_apply_merge_diff` | Encode, apply, merge, and diff V1 state updates. | 120 | 12.04 |
| `text_fragmented_delta_render` | Render a large fragmented formatted text value as a delta. | 120 | 9.53 |
| `advanced_undo_redo_stack` | Create undo stack items, undo, redo, and clear stacks. | 120 | 5.34 |

## License

Apache License 2.0. Copyright 2026 Mike Diarmid.
