class ViolatorInfo {
  final int isN;
  final String? altKatName;
  final String? katName;
  final String? qeyd;

  ViolatorInfo({
    required this.isN,
    this.altKatName,
    this.katName,
    this.qeyd,
  });

  factory ViolatorInfo.fromJson(Map<String, dynamic> json) {
    return ViolatorInfo(
      isN: (json['is_N'] as num?)?.toInt() ?? 0,
      altKatName: json['altKatName'] as String?,
      katName: json['katName'] as String?,
      qeyd: json['qeyd'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_N': isN,
        'altKatName': altKatName,
        'katName': katName,
        'qeyd': qeyd,
      };

  bool get hasViolation =>
      altKatName != null || katName != null || qeyd != null;
}
