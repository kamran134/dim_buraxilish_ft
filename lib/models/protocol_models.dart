/// Protocol related data models for the DIM Buraxilish application
/// Handles Protocol, NoteType and related API responses
///
/// Author: GitHub Copilot
/// Date: 2025-10-13

/// Note type model representing different categories of protocol notes
class NoteType {
  final int id;
  final String name;

  const NoteType({
    required this.id,
    required this.name,
  });

  factory NoteType.fromJson(Map<String, dynamic> json) {
    return NoteType(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() => 'NoteType(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteType &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

/// Protocol note model representing individual protocol entries
class ProtocolNote {
  final int id;
  final int bina;
  final int noteTypeId;
  final String noteTypeName;
  final String note;
  final String createdAt;
  final String updatedAt;
  final String examDate;

  const ProtocolNote({
    required this.id,
    required this.bina,
    required this.noteTypeId,
    required this.noteTypeName,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.examDate,
  });

  factory ProtocolNote.fromJson(Map<String, dynamic> json) {
    return ProtocolNote(
      id: json['id'] as int,
      bina: json['bina'] as int,
      noteTypeId: json['noteTypeId'] as int,
      noteTypeName: json['noteTypeName'] as String,
      note: json['note'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      examDate: json['examDate'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bina': bina,
      'noteTypeId': noteTypeId,
      'noteTypeName': noteTypeName,
      'note': note,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'examDate': examDate,
    };
  }

  @override
  String toString() {
    return 'ProtocolNote(id: $id, bina: $bina, noteTypeId: $noteTypeId, '
        'noteTypeName: $noteTypeName, note: $note, createdAt: $createdAt, '
        'updatedAt: $updatedAt, examDate: $examDate)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProtocolNote &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bina == other.bina &&
          noteTypeId == other.noteTypeId &&
          noteTypeName == other.noteTypeName &&
          note == other.note &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          examDate == other.examDate;

  @override
  int get hashCode {
    return id.hashCode ^
        bina.hashCode ^
        noteTypeId.hashCode ^
        noteTypeName.hashCode ^
        note.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        examDate.hashCode;
  }
}

/// Request model for creating new protocol notes (used by monitors)
class CreateProtocolNoteRequest {
  final String note;
  final String examDate;
  final int noteTypeId;

  const CreateProtocolNoteRequest({
    required this.note,
    required this.examDate,
    required this.noteTypeId,
  });

  factory CreateProtocolNoteRequest.fromJson(Map<String, dynamic> json) {
    return CreateProtocolNoteRequest(
      note: json['note'] as String,
      examDate: json['examDate'] as String,
      noteTypeId: json['noteTypeId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'note': note,
      'examDate': examDate,
      'noteTypeId': noteTypeId,
    };
  }

  @override
  String toString() {
    return 'CreateProtocolNoteRequest(note: $note, examDate: $examDate, '
        'noteTypeId: $noteTypeId)';
  }
}

/// Request model for updating existing protocol notes (used by monitors)
class UpdateProtocolNoteRequest {
  final int id;
  final String note;
  final String examDate;
  final int noteTypeId;

  const UpdateProtocolNoteRequest({
    required this.id,
    required this.note,
    required this.examDate,
    required this.noteTypeId,
  });

  factory UpdateProtocolNoteRequest.fromJson(Map<String, dynamic> json) {
    return UpdateProtocolNoteRequest(
      id: json['id'] as int,
      note: json['note'] as String,
      examDate: json['examDate'] as String,
      noteTypeId: json['noteTypeId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note': note,
      'examDate': examDate,
      'noteTypeId': noteTypeId,
    };
  }

  @override
  String toString() {
    return 'UpdateProtocolNoteRequest(id: $id, note: $note, examDate: $examDate, '
        'noteTypeId: $noteTypeId)';
  }
}

/// Model for protocol reports (used by admins)
class ProtocolReport {
  final int bina;
  final String noteTypeName;
  final String note;
  final String examDate;
  final String createdAt;
  final String updatedAt;

  const ProtocolReport({
    required this.bina,
    required this.noteTypeName,
    required this.note,
    required this.examDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProtocolReport.fromJson(Map<String, dynamic> json) {
    return ProtocolReport(
      bina: json['bina'] as int,
      noteTypeName: json['noteTypeName'] as String,
      note: json['note'] as String,
      examDate: json['examDate'] as String,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bina': bina,
      'noteTypeName': noteTypeName,
      'note': note,
      'examDate': examDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  @override
  String toString() {
    return 'ProtocolReport(bina: $bina, noteTypeName: $noteTypeName, '
        'note: $note, examDate: $examDate, createdAt: $createdAt, '
        'updatedAt: $updatedAt)';
  }
}

/// Response model for paginated protocol data
class ProtocolsResponse {
  final bool success;
  final String? message;
  final ProtocolsData? data;

  const ProtocolsResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory ProtocolsResponse.fromJson(Map<String, dynamic> json) {
    return ProtocolsResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      data: json['data'] != null
          ? ProtocolsData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.toJson(),
    };
  }
}

/// Paginated data wrapper for protocols
class ProtocolsData {
  final List<ProtocolNote> data;
  final int totalCount;
  final int pageCount;
  final int currentPage;
  final int pageSize;

  const ProtocolsData({
    required this.data,
    required this.totalCount,
    required this.pageCount,
    required this.currentPage,
    required this.pageSize,
  });

  factory ProtocolsData.fromJson(Map<String, dynamic> json) {
    return ProtocolsData(
      data: (json['data'] as List<dynamic>)
          .map((e) => ProtocolNote.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int,
      pageCount: json['pageCount'] as int,
      currentPage: json['currentPage'] as int,
      pageSize: json['pageSize'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((e) => e.toJson()).toList(),
      'totalCount': totalCount,
      'pageCount': pageCount,
      'currentPage': currentPage,
      'pageSize': pageSize,
    };
  }
}

/// Response model for note types
class NoteTypesResponse {
  final bool success;
  final String? message;
  final List<NoteType>? data;

  const NoteTypesResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory NoteTypesResponse.fromJson(Map<String, dynamic> json) {
    return NoteTypesResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      data: json['data'] != null
          ? (json['data'] as List<dynamic>)
              .map((e) => NoteType.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.map((e) => e.toJson()).toList(),
    };
  }
}

/// Response model for single protocol operations
class ProtocolResponse {
  final bool success;
  final String? message;
  final ProtocolNote? data;

  const ProtocolResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory ProtocolResponse.fromJson(Map<String, dynamic> json) {
    return ProtocolResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      data: json['data'] != null
          ? ProtocolNote.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data?.toJson(),
    };
  }
}
