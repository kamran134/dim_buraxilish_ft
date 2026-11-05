import 'dart:typed_data';

import 'package:dim_buraxilish_ft/services/bxp1_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _record(int card, List<int> data) {
  final bd = ByteData(12);
  bd.setInt64(0, card, Endian.little);
  bd.setInt32(8, data.length, Endian.little);
  return Uint8List.fromList([...bd.buffer.asUint8List(), ...data]);
}

Uint8List _stream(int count, List<Uint8List> records, {String magic = 'BXP1'}) {
  final header = ByteData(4)..setInt32(0, count, Endian.little);
  return Uint8List.fromList([
    ...magic.codeUnits,
    ...header.buffer.asUint8List(),
    for (final r in records) ...r,
  ]);
}

Stream<Uint8List> _chunked(Uint8List bytes, int size) async* {
  for (var i = 0; i < bytes.length; i += size) {
    final end = i + size < bytes.length ? i + size : bytes.length;
    yield Uint8List.sublistView(bytes, i, end);
  }
}

void main() {
  final records = [
    _record(101, [1, 2, 3]),
    _record(102, List.filled(50, 7)),
    _record(103, [9]),
  ];
  final full = _stream(3, records);

  Future<(Bxp1Result, List<int>)> parse(Stream<Uint8List> s,
      {int batchSize = 20, List<int>? batchSizes}) async {
    final cards = <int>[];
    final result = await parseBxp1Stream(
      s,
      batchSize: batchSize,
      onBatch: (batch) async {
        batchSizes?.add(batch.length);
        cards.addAll(batch.map((e) => e.key));
      },
    );
    return (result, cards);
  }

  group('parseBxp1Stream', () {
    for (final size in [1, 2, 5, 13, 1000]) {
      test('parses a stream split into chunks of $size bytes', () async {
        final (result, cards) = await parse(_chunked(full, size));
        expect(result.received, 3);
        expect(result.count, 3);
        expect(cards, [101, 102, 103]);
      });
    }

    test('hands out full batches and the remainder', () async {
      final sizes = <int>[];
      await parse(_chunked(full, 4), batchSize: 2, batchSizes: sizes);
      expect(sizes, [2, 1]);
    });

    test('keeps photo bytes intact', () async {
      final got = <int, Uint8List>{};
      await parseBxp1Stream(_chunked(full, 3), onBatch: (batch) async {
        for (final e in batch) {
          got[e.key] = e.value;
        }
      });
      expect(got[101], [1, 2, 3]);
      expect(got[102], List.filled(50, 7));
    });

    test('rejects a wrong magic', () async {
      final bad = _stream(1, [_record(1, [1])], magic: 'XXXX');
      expect(parse(_chunked(bad, 3)), throwsA(isA<FormatException>()));
    });

    test('rejects a non-positive record length', () async {
      final bad = _stream(1, [_record(1, [])]);
      expect(parse(_chunked(bad, 3)), throwsA(isA<FormatException>()));
    });

    test('throws when the stream ends mid-record', () async {
      final cut = Uint8List.sublistView(full, 0, full.length - 3);
      expect(parse(_chunked(cut, 7)), throwsA(isA<FormatException>()));
    });

    test('throws when the stream ends mid-record header', () async {
      final first = records.first;
      final cut = Uint8List.fromList([
        ..._stream(3, [first]),
        1, 2, 3, // stray bytes, not a full 12-byte header
      ]);
      expect(parse(_chunked(cut, 7)), throwsA(isA<FormatException>()));
    });

    test('throws on an empty stream', () async {
      expect(parse(const Stream<Uint8List>.empty()),
          throwsA(isA<FormatException>()));
    });

    test('a stream shorter than count returns received < count without error',
        () async {
      final short = _stream(5, records);
      final (result, cards) = await parse(_chunked(short, 6));
      expect(result.received, 3);
      expect(result.count, 5);
      expect(cards, [101, 102, 103]);
    });

    test('count 0 yields nothing', () async {
      final (result, cards) = await parse(_chunked(_stream(0, []), 2));
      expect(result.received, 0);
      expect(result.count, 0);
      expect(cards, isEmpty);
    });

    test('hands out the incomplete batch before rethrowing a stream error',
        () async {
      Stream<Uint8List> failing() async* {
        // Two whole records, then the connection dies.
        yield Uint8List.fromList([
          ..._stream(3, [records[0], records[1]]),
        ]);
        throw StateError('connection lost');
      }

      final cards = <int>[];
      await expectLater(
        parseBxp1Stream(failing(), onBatch: (batch) async {
          cards.addAll(batch.map((e) => e.key));
        }),
        throwsA(isA<StateError>()),
      );
      expect(cards, [101, 102]);
    });

    test('hands out the incomplete batch before rethrowing corruption',
        () async {
      final corrupt = Uint8List.fromList([
        ..._stream(3, [records[0]]),
        ..._record(2, []), // zero length -> FormatException
      ]);
      final cards = <int>[];
      await expectLater(
        parseBxp1Stream(_chunked(corrupt, 5), onBatch: (batch) async {
          cards.addAll(batch.map((e) => e.key));
        }),
        throwsA(isA<FormatException>()),
      );
      expect(cards, [101]);
    });

    test('does not hand a batch out twice when onBatch itself fails',
        () async {
      var calls = 0;
      await expectLater(
        parseBxp1Stream(_chunked(full, 4), batchSize: 1, onBatch: (b) async {
          calls++;
          throw StateError('disk full');
        }),
        throwsA(isA<StateError>()),
      );
      expect(calls, 1);
    });
  });
}
