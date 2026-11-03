/// Protocol (rule-violation) record of one participant, from
/// `buraxilishes/getparticipantprotocol`.
class ParticipantProtocolDto {
  final String? altKatName;
  final String? katName;
  final String? qeyd;
  final String? examName;
  final DateTime? examDate;
  final DateTime? changeActivityDate;
  final String? changeActivityInfo;

  const ParticipantProtocolDto({
    this.altKatName,
    this.katName,
    this.qeyd,
    this.examName,
    this.examDate,
    this.changeActivityDate,
    this.changeActivityInfo,
  });

  factory ParticipantProtocolDto.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final value = json[key];
      return value is String ? DateTime.tryParse(value) : null;
    }

    return ParticipantProtocolDto(
      altKatName: json['altKatName'] as String?,
      katName: json['katName'] as String?,
      qeyd: json['qeyd'] as String?,
      examName: json['imt_Adi'] as String?,
      examDate: date('imt_Date'),
      changeActivityDate: date('changeAktivity_Date'),
      changeActivityInfo: json['changeAktivity_Info'] as String?,
    );
  }

  /// True when the server returned a record with at least one visible field.
  bool get hasContent =>
      [
        altKatName,
        katName,
        qeyd,
        examName,
        changeActivityInfo,
      ].any((value) => value != null && value.isNotEmpty) ||
      examDate != null ||
      changeActivityDate != null;
}
