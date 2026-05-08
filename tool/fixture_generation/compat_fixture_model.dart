part of generate_fixtures;

final class _FixtureDefinition {
  const _FixtureDefinition({
    required this.id,
    required this.category,
    required this.description,
    required this.updateDoc,
    required this.stateVector,
    required this.snapshot,
    required this.relativePosition,
    required this.idMap,
    required this.contentMap,
    required this.expected,
  });

  final String id;
  final String category;
  final String description;
  final Doc updateDoc;
  final Map<int, int> stateVector;
  final Snapshot snapshot;
  final RelativePosition relativePosition;
  final IdMap idMap;
  final ContentMap contentMap;
  final Map<String, Object?> expected;
}
