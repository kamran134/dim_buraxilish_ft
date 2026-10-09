import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/participant_models.dart';
import '../../services/database_service.dart';
import '../../models/violator_models.dart';
import '../../design/app_colors.dart';

/// Карточка участника для отображения в списке статистики
class ParticipantCard extends StatelessWidget {
  final Participant participant;
  final bool isRegistered;
  final ViolatorInfo? violatorInfo;
  final VoidCallback? onCancel;

  const ParticipantCard({
    Key? key,
    required this.participant,
    this.isRegistered = true,
    this.violatorInfo,
    this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasViolation = violatorInfo != null && violatorInfo!.hasViolation;
    final borderColor = hasViolation
        ? Colors.orange.shade600
        : (isRegistered ? AppColors.successGreen : Colors.red.shade400);
    final bgColor = hasViolation
        ? Colors.orange.withOpacity(0.10)
        : (isRegistered
            ? Colors.green.withOpacity(0.07)
            : Colors.red.withOpacity(0.07));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Stack(
        children: [
          // Main content
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, isRegistered ? 44 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _ParticipantAvatar(participant: participant),
                    ),
                    const SizedBox(width: 12),
                    // Name block
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${participant.lastName} ${participant.firstName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (participant.fatherName.isNotEmpty)
                            Text(
                              participant.fatherName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28), // space for corner badge
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.badge,
                  'İş nömrəsi',
                  participant.cardNumber.toString(),
                ),
                _buildInfoRow(
                  Icons.access_time,
                  'Qeydiyyat vaxtı',
                  _formatDate(participant.registeredAt),
                ),
                _buildInfoRow(
                  Icons.location_on,
                  'Yer',
                  '${participant.buildingCode} - ${participant.hall} - ${participant.floor} - ${participant.row} - ${participant.seat}',
                ),
                if (hasViolation) _buildViolationRow(violatorInfo!),
              ],
            ),
          ),
          // Corner status badge
          Positioned(
            top: 8,
            right: 8,
            child: hasViolation
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('DİQQƏT',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                : Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: borderColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isRegistered ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
          ),
          // Cancel button (only for registered)
          if (isRegistered && onCancel != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Təsdiq'),
                      content: const Text(
                          'Qeydiyyatını ləğv etmək istədiyinizdən əminsinizmi?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Xeyr'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Bəli',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) onCancel!();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel_outlined,
                          size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Ləğv et',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViolationRow(ViolatorInfo violation) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade600, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.orange.shade300),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Əvvəlki imtahanlarda qayda pozuntusuna yol verib',
                  style: TextStyle(
                    color: Colors.orange.shade200,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nəzarətdə saxlanılsın',
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'null') {
      return 'Məlum deyil';
    }
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}

/// 50px avatar. Uses the photo carried by [participant] when present (base64
/// from the sync queue / online responses, or bytes); otherwise loads the BLOB
/// for this one participant from the offline DB — the list query skips photos
/// (see DatabaseService.getAllParticipantsWithoutPhotos).
class _ParticipantAvatar extends StatefulWidget {
  final Participant participant;

  const _ParticipantAvatar({required this.participant});

  @override
  State<_ParticipantAvatar> createState() => _ParticipantAvatarState();
}

class _ParticipantAvatarState extends State<_ParticipantAvatar> {
  // Small LRU so scrolling back doesn't re-query; null = "no photo" (cached
  // too, so rows without a photo aren't re-queried on every rebuild).
  static const int _cacheSize = 120;
  static final Map<int, Uint8List?> _cache = <int, Uint8List?>{};

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_ParticipantAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.participant.cardNumber != widget.participant.cardNumber) {
      _resolve();
    }
  }

  void _resolve() {
    final inline = _inlineBytes(widget.participant);
    if (inline != null) {
      _bytes = inline;
      return;
    }
    final card = widget.participant.cardNumber;
    if (_cache.containsKey(card)) {
      // Re-insert to mark as most recently used.
      _bytes = _cache.remove(card);
      _cache[card] = _bytes;
      return;
    }
    _bytes = null;
    DatabaseService.getParticipantPhoto(card).then((bytes) {
      _cache[card] = bytes;
      while (_cache.length > _cacheSize) {
        _cache.remove(_cache.keys.first);
      }
      if (mounted && widget.participant.cardNumber == card) {
        setState(() => _bytes = bytes);
      }
    }).catchError((_) {});
  }

  static Uint8List? _inlineBytes(Participant p) {
    final bytes = p.photoBytes;
    if (bytes != null && bytes.isNotEmpty) return bytes;
    final b64 = p.photo;
    if (b64 == null || b64.isEmpty || b64 == 'null') return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(Icons.person, color: Colors.white, size: 24);
    final bytes = _bytes;
    if (bytes == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Image.memory(
        bytes,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        // Decode at avatar size, not the full photo resolution.
        cacheWidth: 150,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}
