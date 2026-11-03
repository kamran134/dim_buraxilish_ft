import 'participant_light_dto.dart';

/// One page of `buraxilishes/getallparticipantswithpagination` /
/// `buraxilishes/searchparticipants` (`PaginatedResultDto<ParticipantLightDto>`).
class ParticipantsPage {
  final List<ParticipantLightDto> items;
  final int totalCount;
  final int totalPages;
  final bool hasNextPage;

  const ParticipantsPage({
    required this.items,
    required this.totalCount,
    required this.totalPages,
    required this.hasNextPage,
  });

  factory ParticipantsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return ParticipantsPage(
      items: [
        for (final item in raw)
          ParticipantLightDto.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      totalCount: (json['totalCount'] as num?)?.toInt() ?? raw.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
    );
  }
}
