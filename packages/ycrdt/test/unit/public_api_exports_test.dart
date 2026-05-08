import 'package:test/test.dart';
import 'package:ycrdt/ycrdt.dart';

void main() {
  test('exports stable public placeholders and relative positions', () {
    expect(packageName, 'ycrdt');

    final position = RelativePosition.root('body');

    expect(decodeRelativePosition(encodeRelativePosition(position)), position);
    expect(decodeSnapshot(encodeSnapshot(emptySnapshot)), emptySnapshot);
    expect(snapshotContainsUpdate(emptySnapshot, const [0, 0]), isTrue);
    expect(const SnapshotRestoreException('x').reason, 'x');
    expect(StackItem().isEmpty, isTrue);
    expect(noAttributionManager, isA<AttributionManager>());
    expect(Attributions.empty().isEmpty, isTrue);
    expect(
      createAttributionManagerFromSnapshots(emptySnapshot),
      isA<SnapshotAttributionManager>(),
    );
  });
}
