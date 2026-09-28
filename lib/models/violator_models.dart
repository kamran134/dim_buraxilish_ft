class ViolatorInfo {
  final int cardNumber;
  final String? altKatName;
  final String? katName;
  final String? qeyd;

  ViolatorInfo({
    required this.cardNumber,
    this.altKatName,
    this.katName,
    this.qeyd,
  });

  factory ViolatorInfo.fromJson(Map<String, dynamic> json) {
    return ViolatorInfo(
      cardNumber: (json['cardNumber'] as num?)?.toInt() ?? 0,
      altKatName: json['altKatName'] as String?,
      katName: json['katName'] as String?,
      qeyd: json['qeyd'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        // Local-only persistence key (participant_violations.is_N) — not part
        // of the server wire contract, kept as-is; see DatabaseService.
        'is_N': cardNumber,
        'altKatName': altKatName,
        'katName': katName,
        'qeyd': qeyd,
      };

  bool get hasViolation =>
      altKatName != null || katName != null || qeyd != null;
}
