/// Protocol Notes Screen for Monitors
/// Allows monitors to add and edit protocol notes during exams
///
/// Author: GitHub Copilot
/// Date: 2025-10-13

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/protocol_models.dart';
import '../providers/auth_provider.dart';
import '../services/protocol_service.dart';
import '../services/http_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/common/common_widgets.dart';
import '../widgets/common/custom_bottom_navigation.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';
import 'participant_screen.dart';
import 'supervisor_screen.dart';
import 'statistics_screen.dart';

class ProtocolNotesScreen extends StatefulWidget {
  const ProtocolNotesScreen({super.key});

  @override
  State<ProtocolNotesScreen> createState() => _ProtocolNotesScreenState();
}

class _ProtocolNotesScreenState extends State<ProtocolNotesScreen> {
  late ProtocolService _protocolService;
  List<ProtocolNote> _notes = [];
  List<NoteType> _noteTypes = [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _showAddForm = false;

  // Add note form
  final _noteController = TextEditingController();
  int _selectedNoteTypeId = 1;

  // Edit note form
  int? _editingNoteId;
  final _editNoteController = TextEditingController();
  int _editSelectedNoteTypeId = 1;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _protocolService = ProtocolService(HttpService());
    _loadInitialData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _editNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadNoteTypes();
    await _loadNotes();
  }

  Future<void> _loadNoteTypes() async {
    try {
      final response = await _protocolService.getNoteTypes();
      if (response.success && response.data != null) {
        setState(() {
          _noteTypes = response.data!;
          if (_noteTypes.isNotEmpty) {
            _selectedNoteTypeId = _noteTypes.first.id;
            _editSelectedNoteTypeId = _noteTypes.first.id;
          }
        });
      }
    } catch (e) {
      print('Error loading note types: $e');
      // Use default note type if loading fails
      if (mounted) {
        _showSnackBar('Qeyd növləri yüklənmədi', isError: true);
      }
    }
  }

  Future<void> _loadNotes() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final examDate = authProvider.authData?.examDate;

      final notes = await _protocolService.getMyProtocolNotes(
        examDate: examDate,
      );

      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Qeydlər yüklənmədi', isError: true);
      }
    }
  }

  Future<void> _addNote() async {
    if (_noteController.text.trim().isEmpty) {
      _showSnackBar('Qeyd mətni boş ola bilməz', isError: true);
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final examDate = authProvider.authData?.examDate;

      if (examDate == null || examDate.isEmpty) {
        _showSnackBar('İmtahan tarixi tapılmadı', isError: true);
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // Convert to ISO format
      final isoDate = DateFormatter.azerbaijaniDateToISO(examDate);
      if (isoDate == null) {
        _showSnackBar('Tarix formatı yanlışdır', isError: true);
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final request = CreateProtocolNoteRequest(
        note: _noteController.text.trim(),
        examDate: isoDate,
        noteTypeId: _selectedNoteTypeId,
      );

      final response = await _protocolService.createProtocolNote(request);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (response.success) {
          _showSnackBar('Qeyd uğurla əlavə edildi');
          _hideAddForm();
          await _loadNotes();
        } else {
          _showSnackBar(response.message ?? 'Qeyd əlavə edilmədi',
              isError: true);
        }
      }
    } catch (e) {
      print('Error adding note: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showSnackBar('Qeyd əlavə edərkən xəta baş verdi', isError: true);
      }
    }
  }

  Future<void> _updateNote() async {
    if (_editNoteController.text.trim().isEmpty) {
      _showSnackBar('Qeyd mətni boş ola bilməz', isError: true);
      return;
    }

    if (_isUpdating || _editingNoteId == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final examDate = authProvider.authData?.examDate;

      if (examDate == null || examDate.isEmpty) {
        _showSnackBar('İmtahan tarixi tapılmadı', isError: true);
        setState(() {
          _isUpdating = false;
        });
        return;
      }

      // Convert to ISO format
      final isoDate = DateFormatter.azerbaijaniDateToISO(examDate);
      if (isoDate == null) {
        _showSnackBar('Tarix formatı yanlışdır', isError: true);
        setState(() {
          _isUpdating = false;
        });
        return;
      }

      final request = UpdateProtocolNoteRequest(
        id: _editingNoteId!,
        note: _editNoteController.text.trim(),
        examDate: isoDate,
        noteTypeId: _editSelectedNoteTypeId,
      );

      final response = await _protocolService.updateProtocolNote(request);

      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        if (response.success) {
          _showSnackBar('Qeyd uğurla yeniləndi');
          _cancelEdit();
          await _loadNotes();
        } else {
          _showSnackBar(response.message ?? 'Qeyd yenilənmədi', isError: true);
        }
      }
    } catch (e) {
      print('Error updating note: $e');
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
        _showSnackBar('Qeyd yeniləyərkən xəta baş verdi', isError: true);
      }
    }
  }

  void _showAddFormDialog() {
    setState(() {
      _showAddForm = true;
      _noteController.clear();
      if (_noteTypes.isNotEmpty) {
        _selectedNoteTypeId = _noteTypes.first.id;
      }
    });
  }

  void _hideAddForm() {
    setState(() {
      _showAddForm = false;
      _noteController.clear();
    });
  }

  void _startEdit(ProtocolNote note) {
    setState(() {
      _editingNoteId = note.id;
      _editNoteController.text = note.note;
      _editSelectedNoteTypeId = note.noteTypeId;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingNoteId = null;
      _editNoteController.clear();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: GradientBackground(
        gradientType: GradientType.participant,
        isDarkMode: isDarkMode,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              ScreenHeader(
                title: 'Protokol qeydləri',
                showBackButton: true,
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Add Note Button
                      if (!_showAddForm) _buildAddButton(isDarkMode),

                      // Add Note Form
                      if (_showAddForm) _buildAddForm(isDarkMode),

                      const SizedBox(height: 16),

                      // Notes List
                      Expanded(
                        child: _buildNotesList(isDarkMode),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(context),
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return CustomBottomNavigation(
      items: [
        BottomNavItem(
          icon: Icons.school,
          label: 'İştirakçılar',
          isSelected: false,
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ParticipantScreen(),
              ),
            );
          },
        ),
        BottomNavItem(
          icon: Icons.supervisor_account,
          label: 'Nəzarətçilər',
          isSelected: false,
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const SupervisorScreen(),
              ),
            );
          },
        ),
        BottomNavItem(
          icon: Icons.analytics,
          label: 'Statistika',
          isSelected: false,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const StatisticsScreen(),
              ),
            );
          },
        ),
        BottomNavItem(
          icon: Icons.assignment,
          label: 'Protokollar',
          isSelected: true, // Текущий экран
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildAddButton(bool isDarkMode) {
    return AnimatedWrapper(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        child: ElevatedButton.icon(
          onPressed: _showAddFormDialog,
          icon: const Icon(Icons.add),
          label: const Text('Yeni qeyd əlavə et'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddForm(bool isDarkMode) {
    return AnimatedWrapper(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(isDarkMode ? 0.1 : 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni qeyd',
              style: AppTextStyles.heading2.copyWith(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Note Type Dropdown
            if (_noteTypes.isNotEmpty)
              DropdownButtonFormField<int>(
                value: _selectedNoteTypeId,
                decoration: InputDecoration(
                  labelText: 'Qeyd növü',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.8),
                ),
                items: _noteTypes.map((type) {
                  return DropdownMenuItem<int>(
                    value: type.id,
                    child: Text(type.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedNoteTypeId = value;
                    });
                  }
                },
              ),
            const SizedBox(height: 16),

            // Note Text Field
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Qeyd mətni',
                hintText: 'Qeydınızı daxil edin...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _addNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Saxla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _hideAddForm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDarkMode ? Colors.white : Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Ləğv et'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList(bool isDarkMode) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Hələ heç bir qeyd yoxdur',
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        final isEditing = _editingNoteId == note.id;

        return AnimatedWrapper(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isDarkMode ? 0.1 : 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isEditing
                ? _buildEditForm(note, isDarkMode)
                : _buildNoteView(note, isDarkMode),
          ),
        );
      },
    );
  }

  Widget _buildNoteView(ProtocolNote note, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with type and date
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                note.noteTypeName,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            Text(
              DateFormatter.formatISOToAz(note.createdAt),
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Note content
        Text(
          note.note,
          style: AppTextStyles.bodyLarge.copyWith(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // Action buttons
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _startEdit(note),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Redaktə et'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            if (note.updatedAt != note.createdAt)
              Text(
                'Redaktə: ${DateFormatter.formatISOToAz(note.updatedAt)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm(ProtocolNote note, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Qeydi redaktə et',
          style: AppTextStyles.heading3.copyWith(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Note Type Dropdown
        if (_noteTypes.isNotEmpty)
          DropdownButtonFormField<int>(
            value: _editSelectedNoteTypeId,
            decoration: InputDecoration(
              labelText: 'Qeyd növü',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
            ),
            items: _noteTypes.map((type) {
              return DropdownMenuItem<int>(
                value: type.id,
                child: Text(type.name),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _editSelectedNoteTypeId = value;
                });
              }
            },
          ),
        const SizedBox(height: 16),

        // Note Text Field
        TextField(
          controller: _editNoteController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Qeyd mətni',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateNote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Saxla'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _isUpdating ? null : _cancelEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Ləğv et'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
