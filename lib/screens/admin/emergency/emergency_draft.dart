import 'package:flutter/material.dart';

import '../../../models/admin_models.dart';

/// The emergency message being composed: texts, importance and recipients.
/// Owned by the loader so it survives switching between the Göndər and
/// Tarixçə tabs.
class EmergencyDraft extends ChangeNotifier {
  static const int maxTitleLength = 100;
  static const int maxBodyLength = 500;

  final TextEditingController title = TextEditingController();
  final TextEditingController body = TextEditingController();

  EmergencyImportance _importance = EmergencyImportance.info;
  bool _sendToAll = true;
  final Set<String> _selected = {};
  String _buildingQuery = '';

  EmergencyDraft() {
    title.addListener(notifyListeners);
    body.addListener(notifyListeners);
  }

  EmergencyImportance get importance => _importance;
  bool get sendToAll => _sendToAll;
  Set<String> get selected => Set.unmodifiable(_selected);
  String get buildingQuery => _buildingQuery;

  bool get hasText =>
      title.text.trim().isNotEmpty && body.text.trim().isNotEmpty;

  /// Both texts are filled and, unless it goes to everyone, at least one
  /// building is picked.
  bool get canSend => hasText && (_sendToAll || _selected.isNotEmpty);

  /// Codes to send to; empty = all buildings.
  List<String> get buildingCodes =>
      _sendToAll ? const [] : (_selected.toList()..sort());

  void setImportance(EmergencyImportance value) {
    _importance = value;
    notifyListeners();
  }

  void setSendToAll(bool value) {
    _sendToAll = value;
    if (value) _selected.clear();
    notifyListeners();
  }

  void toggle(String code) {
    if (!_selected.remove(code)) _selected.add(code);
    notifyListeners();
  }

  /// Selects every code of [codes], or deselects them when all are already
  /// selected (the "select all" box of the building list applies to the
  /// buildings the search currently shows).
  void toggleAll(Iterable<String> codes) {
    final list = codes.toList();
    if (list.isEmpty) return;
    if (list.every(_selected.contains)) {
      _selected.removeAll(list);
    } else {
      _selected.addAll(list);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  void setBuildingQuery(String value) {
    _buildingQuery = value;
    notifyListeners();
  }

  /// Back to an empty message for everyone.
  void reset() {
    title.clear();
    body.clear();
    _importance = EmergencyImportance.info;
    _sendToAll = true;
    _selected.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }
}
