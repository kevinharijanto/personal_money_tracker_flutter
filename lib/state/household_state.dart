import 'package:flutter/foundation.dart';

import '../models/household.dart';
import '../services/household_service.dart';
import '../services/api_client.dart';
import '../storage/auth_storage.dart';

class HouseholdState extends ChangeNotifier {
  final HouseholdService _householdService;

  HouseholdState({HouseholdService? householdService})
    : _householdService = householdService ?? HouseholdService() {
    _init();
  }

  bool _isLoading = false;
  String? _error;
  List<Household> _households = [];
  String? _selectedHouseholdId;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Household> get households => _households;
  String? get selectedHouseholdId => _selectedHouseholdId;
  Household? get selectedHousehold {
    if (_selectedHouseholdId == null) return null;
    try {
      return _households.firstWhere((h) => h.id == _selectedHouseholdId);
    } catch (_) {
      return null;
    }
  }

  bool get hasData => _households.isNotEmpty;

  Future<void> _init() async {
    await load();
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched = await _householdService.fetchHouseholds();
      _households = fetched;

      String? selected = await AuthStorage.getHouseholdId();
      if (selected == null ||
          selected.isEmpty ||
          !_households.any((h) => h.id == selected)) {
        selected = _households.isNotEmpty ? _households.first.id : null;
        if (selected != null) {
          await AuthStorage.setHouseholdId(selected);
        }
      }

      _selectedHouseholdId = selected;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _households = [];
    notifyListeners();
    await load();
  }

  Future<void> selectHousehold(String householdId) async {
    if (_selectedHouseholdId == householdId) return;
    _selectedHouseholdId = householdId;
    notifyListeners();
    await AuthStorage.setHouseholdId(householdId);
    ApiClient.clearAllCache();
  }

  Future<void> renameHousehold({
    required String householdId,
    required String newName,
  }) async {
    final updated = await _householdService.renameHousehold(
      householdId: householdId,
      name: newName,
    );

    final index = _households.indexWhere((h) => h.id == householdId);
    if (index != -1) {
      _households[index] = updated;
      notifyListeners();
    }
  }

  void clear() {
    _households = [];
    _selectedHouseholdId = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
