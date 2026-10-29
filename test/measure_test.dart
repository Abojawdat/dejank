import 'package:dejank/src/measure.dart';
import 'package:test/test.dart';

void main() {
  test('reads meter lines, also with a device log prefix', () {
    final runs = parseRuns([
      'unrelated output',
      'DEJANK_METER {"name":"search","widget":"ProductTile","builds":4000}',
      'flutter: DEJANK_METER {"name":"search","widget":"Text","builds":214}',
      'DEJANK_METER {"name":"search","frames":{"count":120,"buildMs":9.8,"rasterMs":3.1,"slow":23}}',
    ]);
    expect(runs.keys, ['search']);
    expect(runs['search']!.builds, {'ProductTile': 4000, 'Text': 214});
    expect(runs['search']!.frames, {'count': 120, 'buildMs': 9.8, 'rasterMs': 3.1, 'slow': 23});
  });

  test('compares with the last run', () {
    final before = Run({'ProductTile': 4000, 'Text': 214}, {'count': 120, 'buildMs': 9.8, 'rasterMs': 3.1, 'slow': 23});
    final now = Run({'ProductTile': 0, 'Text': 214}, {'count': 120, 'buildMs': 1.2, 'rasterMs': 3.1, 'slow': 0});
    expect(
      table('search', Run.fromJson(before.toJson()), now),
      'search                          before       now\n'
      'widget builds                    4,214       214  -95%\n'
      '  ProductTile                    4,000         0  -100%\n'
      'frames                             120       120\n'
      '  avg build                     9.8 ms    1.2 ms  -88%\n'
      '  avg raster                    3.1 ms    3.1 ms\n'
      '  slow frames                       23         0  -100%\n',
    );
  });

  test('first run shows the most built widgets', () {
    expect(
      table('search', null, Run({'Text': 5, 'ProductTile': 4000})),
      'search                             now\n'
      'widget builds                    4,005\n'
      '  ProductTile                    4,000\n'
      '  Text                               5\n',
    );
  });
}
