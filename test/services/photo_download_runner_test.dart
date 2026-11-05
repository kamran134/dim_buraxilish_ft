import 'dart:typed_data';

import 'package:dim_buraxilish_ft/services/bxp1_parser.dart';
import 'package:dim_buraxilish_ft/services/photo_download_runner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FatalError implements Exception {}

/// In-memory stand-in for the server + SQLite pair the runner talks to.
class _Fake {
  /// All rows of the set (keys 1..total).
  final int total;

  /// Cards the "server" has a photo for.
  final Set<int> serverHas;

  /// Cards whose photo is already stored locally.
  final Set<int> stored;

  /// Every request the runner made, in order.
  final List<List<int>> requests = [];
  int loadCalls = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  final List<(int, int)> progress = [];
  int retries = 0;

  /// Decides what happens to a request; null = serve it normally.
  Future<PhotoPartResult> Function(
      int requestIndex,
      List<int> cards,
      Future<void> Function(PhotoBatch) onBatch)? behaviour;

  _Fake({required this.total, Set<int>? serverHas, Set<int>? stored})
      : serverHas = serverHas ?? {for (var i = 1; i <= total; i++) i},
        stored = stored ?? {};

  Future<List<int>> loadMissing() async {
    loadCalls++;
    return [
      for (var i = 1; i <= total; i++)
        if (!stored.contains(i)) i
    ];
  }

  Future<void> saveBatch(PhotoBatch batch) async {
    stored.addAll(batch.map((e) => e.key));
  }

  Future<PhotoPartResult> serve(
      List<int> cards, Future<void> Function(PhotoBatch) onBatch) async {
    final found = cards.where(serverHas.contains).toList();
    for (var i = 0; i < found.length; i += 10) {
      final end = i + 10 < found.length ? i + 10 : found.length;
      await onBatch(
          [for (final c in found.sublist(i, end)) MapEntry(c, Uint8List(1))]);
    }
    return PhotoPartResult(received: found.length, serverCount: found.length);
  }

  Future<PhotoPartResult> fetchPart(
      List<int> cards, Future<void> Function(PhotoBatch) onBatch) async {
    final index = requests.length;
    requests.add(List.of(cards));
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      // Let the other workers start so overlapping is observable.
      await Future<void>.delayed(Duration.zero);
      final custom = behaviour;
      if (custom != null) return await custom(index, cards, onBatch);
      return await serve(cards, onBatch);
    } finally {
      inFlight--;
    }
  }

  PhotoDownloadRunner runner() => PhotoDownloadRunner(
        loadMissing: loadMissing,
        fetchPart: fetchPart,
        saveBatch: saveBatch,
        isFatal: (e) => e is _FatalError,
        total: total,
        onProgress: (done, total) => progress.add((done, total)),
        onRetry: () => retries++,
        retryDelay: Duration.zero,
      );
}

void main() {
  test('empty missing list returns true without touching the network',
      () async {
    final fake = _Fake(total: 5, stored: {1, 2, 3, 4, 5});

    expect(await fake.runner().run(), isTrue);
    expect(fake.requests, isEmpty);
    expect(fake.progress, [(5, 5)]);
  });

  test('splits the missing cards into 4 chunks, at most 4 in parallel',
      () async {
    final fake = _Fake(total: 100);

    expect(await fake.runner().run(), isTrue);
    expect(fake.requests.length, 4);
    expect(fake.requests.map((r) => r.length), everyElement(25));
    expect(fake.maxInFlight, 4);
    expect(fake.stored.length, 100);
  });

  test('uneven counts are spread by ceil(n / 4)', () async {
    final fake = _Fake(total: 10);

    await fake.runner().run();
    expect(fake.requests.map((r) => r.length).toList(), [3, 3, 3, 1]);
  });

  test('never asks for more than 500 cards per request', () async {
    final fake = _Fake(total: 4100);

    expect(await fake.runner().run(), isTrue);
    expect(fake.requests.length, 9); // 8 x 500 + 100
    expect(fake.requests.every((r) => r.length <= 500), isTrue);
    expect(fake.maxInFlight, lessThanOrEqualTo(4));
    expect(fake.stored.length, 4100);
  });

  test('resumes: progress starts from what is already stored', () async {
    final fake = _Fake(total: 10, stored: {1, 2, 3, 4, 5, 6});

    expect(await fake.runner().run(), isTrue);
    expect(fake.progress.first, (6, 10));
    expect(fake.progress.last, (10, 10));
    // Only the four missing cards were requested.
    expect(fake.requests.expand((r) => r).toSet(), {7, 8, 9, 10});
  });

  test('a failed chunk is retried for its missing cards only', () async {
    final fake = _Fake(total: 100);
    List<int>? failedChunk;
    fake.behaviour = (index, cards, onBatch) async {
      if (index == 1) {
        failedChunk = List.of(cards);
        throw Exception('connection reset');
      }
      return fake.serve(cards, onBatch);
    };

    expect(await fake.runner().run(), isTrue);
    expect(fake.retries, 1);
    // Round one: 4 chunks. Round two re-requests exactly the failed chunk's
    // cards (re-split over the workers).
    expect(fake.requests.take(4).every((r) => r.length == 25), isTrue);
    expect(fake.requests.skip(4).expand((r) => r).toList(), failedChunk);
    expect(fake.stored.length, 100);
  });

  test('retry after a half-delivered chunk skips the delivered cards',
      () async {
    final fake = _Fake(total: 40);
    late List<int> firstChunk;
    fake.behaviour = (index, cards, onBatch) async {
      if (index == 0) {
        firstChunk = List.of(cards);
        await onBatch(
            [for (final c in cards.take(4)) MapEntry(c, Uint8List(1))]);
        throw Exception('connection reset');
      }
      return fake.serve(cards, onBatch);
    };

    expect(await fake.runner().run(), isTrue);
    expect(fake.requests.skip(4).expand((r) => r).toList(),
        firstChunk.skip(4).toList());
  });

  test('cards without a photo are not requested again and shrink the total',
      () async {
    final fake = _Fake(
      total: 100,
      serverHas: {for (var i = 1; i <= 100; i++) i}..removeAll({1, 2, 3}),
    );
    // Make one chunk (not the one with cards 1-3) fail once, forcing round 2.
    fake.behaviour = (index, cards, onBatch) async {
      if (index == 3) throw Exception('connection reset');
      return fake.serve(cards, onBatch);
    };

    expect(await fake.runner().run(), isTrue);
    final secondRound = fake.requests.skip(4).expand((r) => r).toSet();
    expect(secondRound.intersection({1, 2, 3}), isEmpty);
    expect(fake.progress.last, (97, 97));
  });

  test('a clean chunk with nothing found marks all its cards as no-photo',
      () async {
    final fake = _Fake(total: 8, serverHas: {});

    expect(await fake.runner().run(), isTrue);
    expect(fake.requests.length, 4);
    expect(fake.progress.last, (0, 0));
  });

  test('a stream cut short (received < serverCount) counts as a failure',
      () async {
    final fake = _Fake(total: 8);
    var round = 0;
    fake.behaviour = (index, cards, onBatch) async {
      if (index == 0 && round++ == 0) {
        return const PhotoPartResult(received: 0, serverCount: 2);
      }
      return fake.serve(cards, onBatch);
    };

    expect(await fake.runner().run(), isTrue);
    expect(fake.requests.skip(4).expand((r) => r).toList(),
        fake.requests.first);
    expect(fake.retries, 1);
  });

  test('stalled rounds give up with false after 3 rounds', () async {
    final fake = _Fake(total: 20);
    fake.behaviour = (index, cards, onBatch) async =>
        throw Exception('no connection');

    expect(await fake.runner().run(), isFalse);
    expect(fake.loadCalls, PhotoDownloadRunner.maxStalledRounds);
    expect(fake.requests.length, 4 * PhotoDownloadRunner.maxStalledRounds);
    expect(fake.retries, PhotoDownloadRunner.maxStalledRounds - 1);
    expect(fake.progress.last, (0, 20));
  });

  test('a round with progress resets the stall counter', () async {
    final fake = _Fake(total: 40);
    fake.behaviour = (index, cards, onBatch) async {
      // loadMissing runs once per round before its requests start, so
      // loadCalls doubles as the round number here.
      if (fake.loadCalls == 2) {
        // Round two: every chunk delivers one photo and then fails.
        await onBatch([MapEntry(cards.first, Uint8List(1))]);
      }
      throw Exception('connection reset');
    };

    expect(await fake.runner().run(), isFalse);
    // Round 1 stalls (1), round 2 progresses (0), rounds 3-5 stall (1..3).
    expect(fake.loadCalls, 5);
  });

  test('a fatal error stops new chunks and is rethrown', () async {
    final fake = _Fake(total: 4000); // 8 chunks of 500
    fake.behaviour = (index, cards, onBatch) async {
      if (index == 0) throw _FatalError();
      return fake.serve(cards, onBatch);
    };

    await expectLater(fake.runner().run(), throwsA(isA<_FatalError>()));
    // The three requests already in flight finish; nothing new is started.
    expect(fake.requests.length, 4);
    expect(fake.retries, 0);
  });

  test('a non-fatal error is not rethrown', () async {
    final fake = _Fake(total: 8);
    fake.behaviour = (index, cards, onBatch) async =>
        throw StateError('not fatal');

    expect(await fake.runner().run(), isFalse);
  });
}
