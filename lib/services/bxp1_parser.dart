import 'dart:typed_data';

/// Photos keyed by participant card number, handed out in small groups so a
/// large download never sits in memory all at once.
typedef PhotoBatch = List<MapEntry<int, Uint8List>>;

class Bxp1Result {
  /// Photos actually read from the stream.
  final int received;

  /// Photo count announced in the stream header.
  final int count;

  const Bxp1Result({required this.received, required this.count});
}

/// Parses a BXP1 binary photo stream and hands the photos to [onBatch] in
/// groups of [batchSize], instead of loading everything into memory.
///
/// Wire format (little-endian):
/// ```
/// magic  : 4 bytes ASCII "BXP1"
/// count  : int32
/// record x count:
///   cardNumber : int64
///   len  : int32  (> 0)
///   data : len bytes
/// ```
/// Returns the number of photos actually received next to the announced
/// count. If the stream ends early at a record boundary (server-side race),
/// that's not an error — whatever was read is returned. An EOF in the middle
/// of a record is a [FormatException].
///
/// When the stream fails or the data is corrupt, the photos already parsed
/// but not yet handed out are passed to [onBatch] first, and only then is the
/// error rethrown — so a dropped connection never loses a nearly full batch.
Future<Bxp1Result> parseBxp1Stream(
  Stream<Uint8List> stream, {
  required Future<void> Function(PhotoBatch batch) onBatch,
  int batchSize = 20,
}) async {
  // Accumulator: a queue of not-yet-consumed chunks plus an offset into
  // the first one. take(n) only consumes bytes once at least n are
  // available, so a short read never corrupts the parse state.
  final chunks = <Uint8List>[];
  int chunkOffset = 0;
  int available = 0;

  void addChunk(Uint8List chunk) {
    if (chunk.isEmpty) return;
    chunks.add(chunk);
    available += chunk.length;
  }

  Uint8List? take(int n) {
    if (available < n) return null;
    final result = Uint8List(n);
    var written = 0;
    while (written < n) {
      final chunk = chunks.first;
      final remainingInChunk = chunk.length - chunkOffset;
      final needed = n - written;
      final toCopy = remainingInChunk < needed ? remainingInChunk : needed;
      result.setRange(written, written + toCopy, chunk, chunkOffset);
      written += toCopy;
      chunkOffset += toCopy;
      if (chunkOffset >= chunk.length) {
        chunks.removeAt(0);
        chunkOffset = 0;
      }
    }
    available -= n;
    return result;
  }

  bool magicChecked = false;
  int? count;
  int? pendingCard;
  int? pendingLen;
  int received = 0;
  var batch = <MapEntry<int, Uint8List>>[];

  // Detaches the pending batch before handing it out: if [onBatch] itself
  // throws, the error handler below must not hand the same photos out again.
  Future<void> flush() async {
    if (batch.isEmpty) return;
    final ready = batch;
    batch = <MapEntry<int, Uint8List>>[];
    await onBatch(ready);
  }

  try {
    await for (final rawChunk in stream) {
      addChunk(rawChunk);

      while (true) {
        if (!magicChecked) {
          final magic = take(4);
          if (magic == null) break;
          if (String.fromCharCodes(magic) != 'BXP1') {
            throw const FormatException(
                'Invalid photo stream magic (expected BXP1)');
          }
          magicChecked = true;
        }

        if (count == null) {
          final countBytes = take(4);
          if (countBytes == null) break;
          count = ByteData.sublistView(countBytes).getInt32(0, Endian.little);
        }

        if (received >= count) break;

        if (pendingLen == null) {
          final header = take(12);
          if (header == null) break;
          final bd = ByteData.sublistView(header);
          pendingCard = bd.getInt64(0, Endian.little);
          pendingLen = bd.getInt32(8, Endian.little);
          if (pendingLen <= 0) {
            throw FormatException('Invalid photo record length: $pendingLen');
          }
        }

        final data = take(pendingLen);
        if (data == null) break; // wait for more chunks

        batch.add(MapEntry(pendingCard!, data));
        pendingCard = null;
        pendingLen = null;
        received++;

        if (batch.length >= batchSize) await flush();
      }

      if (count != null && received >= count) break;
    }
  } catch (_) {
    await flush();
    rethrow;
  }

  await flush();

  if (!magicChecked) {
    throw const FormatException('Photo stream ended before magic header');
  }
  if (count == null) {
    throw const FormatException('Photo stream ended before count header');
  }
  if (pendingLen != null) {
    // EOF in the middle of a record's data — genuinely corrupt.
    throw const FormatException('Photo stream ended mid-record');
  }
  if (received < count && available > 0) {
    // Leftover bytes that never formed a complete record header — cut
    // mid-header, not a clean boundary between records.
    throw const FormatException('Photo stream ended mid-record header');
  }

  return Bxp1Result(received: received, count: count);
}
