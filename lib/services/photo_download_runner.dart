import 'bxp1_parser.dart';

/// Outcome of one photo request: how many photos arrived next to how many the
/// server announced it had for the requested cards.
class PhotoPartResult {
  final int received;
  final int serverCount;

  const PhotoPartResult({required this.received, required this.serverCount});
}

/// Downloads the missing photos of one set (participants, supervisors or
/// monitors) in several parallel requests and keeps retrying only what is
/// still missing until everything the server has is stored. No Dio and no SQLite in here — everything arrives through the
/// constructor callbacks, so the whole retry/resume logic is unit-testable.
///
/// Why parallel: on a mobile network one connection to the server is capped
/// at roughly 250 KB/s, while several together add up.
class PhotoDownloadRunner {
  static const int parallelStreams = 4;
  static const int maxCardsPerRequest = 500;

  /// Consecutive rounds without a single new photo before giving up.
  static const int maxStalledRounds = 3;

  /// Keys (card numbers or row ids) of the rows that still have no photo in
  /// the local DB.
  final Future<List<int>> Function() loadMissing;

  /// Requests [cards] from the server and feeds every parsed batch to the
  /// given callback as it arrives.
  final Future<PhotoPartResult> Function(
          List<int> cards, Future<void> Function(PhotoBatch) onBatch)
      fetchPart;

  final Future<void> Function(PhotoBatch) saveBatch;

  /// Errors that make a retry pointless (auth, bad request) — rethrown by
  /// [run] instead of being retried.
  final bool Function(Object error) isFatal;

  /// Number of rows in the set, with or without a photo.
  final int total;
  final void Function(int done, int total)? onProgress;

  /// Called before the pause that precedes a retry round.
  final void Function()? onRetry;
  final Duration retryDelay;

  PhotoDownloadRunner({
    required this.loadMissing,
    required this.fetchPart,
    required this.saveBatch,
    required this.isFatal,
    required this.total,
    this.onProgress,
    this.onRetry,
    this.retryDelay = const Duration(seconds: 2),
  });

  /// true when every photo the server has is stored; false when rounds stalled.
  /// Rethrows the first error for which [isFatal] is true.
  Future<bool> run() async {
    // Cards the server answered "no photo" for in this run only.
    final noPhoto = <int>{};
    var savedThisRun = 0;
    var stalledRounds = 0;
    int? initialMissing;

    void reportProgress() {
      onProgress?.call(
        total - (initialMissing ?? 0) + savedThisRun,
        total - noPhoto.length,
      );
    }

    while (true) {
      final loaded = await loadMissing();
      final missing = loaded.where((c) => !noPhoto.contains(c)).toList();

      if (initialMissing == null) {
        initialMissing = missing.length;
        reportProgress();
      }
      if (missing.isEmpty) return true;

      final chunkSize = _chunkSize(missing.length);
      final queue = <List<int>>[];
      for (var i = 0; i < missing.length; i += chunkSize) {
        final end = i + chunkSize < missing.length ? i + chunkSize : missing.length;
        queue.add(missing.sublist(i, end));
      }

      var savedThisRound = 0;
      var failedChunks = 0;
      Object? fatalError;
      StackTrace? fatalStack;

      Future<void> worker() async {
        while (fatalError == null && queue.isNotEmpty) {
          final chunk = queue.removeAt(0);
          final received = <int>{};
          try {
            final result = await fetchPart(chunk, (batch) async {
              await saveBatch(batch);
              for (final entry in batch) {
                received.add(entry.key);
              }
              savedThisRun += batch.length;
              savedThisRound += batch.length;
              reportProgress();
            });
            if (result.received == result.serverCount) {
              // Clean finish: whoever was asked for but never came has no photo.
              noPhoto.addAll(chunk.where((c) => !received.contains(c)));
              reportProgress();
            } else {
              failedChunks++;
            }
          } catch (e, st) {
            if (isFatal(e)) {
              fatalError ??= e;
              fatalStack ??= st;
            } else {
              failedChunks++;
            }
          }
        }
      }

      await Future.wait(List.generate(parallelStreams, (_) => worker()));

      final fatal = fatalError;
      if (fatal != null) {
        Error.throwWithStackTrace(fatal, fatalStack ?? StackTrace.current);
      }

      if (failedChunks == 0) return true;

      stalledRounds = savedThisRound > 0 ? 0 : stalledRounds + 1;
      if (stalledRounds >= maxStalledRounds) return false;

      onRetry?.call();
      await Future<void>.delayed(retryDelay * (stalledRounds + 1));
    }
  }

  /// `ceil(n / parallelStreams)` capped by [maxCardsPerRequest], so a short
  /// list is still spread over all workers.
  static int _chunkSize(int n) {
    final perWorker = (n + parallelStreams - 1) ~/ parallelStreams;
    return perWorker < maxCardsPerRequest ? perWorker : maxCardsPerRequest;
  }
}
