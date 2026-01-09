import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift.dart';
import '../services/api_service.dart';

class ShiftProvider with ChangeNotifier {
  List<Shift> _shifts = [];
  bool _isLoading = false;
  String? _error;

  List<Shift> get shifts => _shifts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static const String _shiftsKey = 'shifts';

  // API Methods

  // Load shifts from API
  Future<List<Shift>> _loadShiftsFromApi() async {
    try {
      debugPrint('🔄 Loading shifts from API...');

      final shiftsData = await ApiService.getShifts();
      final shifts = shiftsData.map((json) => Shift.fromApiJson(json)).toList();
      debugPrint('✅ Loaded ${shifts.length} shifts from API');
      return shifts;
    } catch (e) {
      debugPrint('❌ Error loading shifts from API: $e');
      rethrow;
    }
  }

  // Create shift via API
  Future<Shift> _createShiftApi(Shift shift) async {
    try {
      debugPrint('📤 Creating shift via API...');

      final responseData = await ApiService.createShift(shift.toApiJson());

      if (responseData.isNotEmpty) {
        final createdShift = Shift.fromApiJson(responseData);
        debugPrint('✅ Shift created successfully with ID: ${createdShift.id}');
        return createdShift;
      } else {
        // Fallback: use the original shift
        final createdShift = shift.copyWith(createdAt: DateTime.now());
        return createdShift;
      }
    } catch (e) {
      debugPrint('❌ Error creating shift via API: $e');
      rethrow;
    }
  }

  // Update shift via API
  Future<Shift> _updateShiftApi(int id, Shift shift) async {
    try {
      debugPrint('📤 Updating shift via API (ID: $id)...');

      final responseData = await ApiService.updateShift(id, shift.toApiJson());

      if (responseData.isNotEmpty) {
        final updatedShift = Shift.fromApiJson(responseData);
        debugPrint('✅ Shift updated successfully');
        return updatedShift;
      } else {
        // Fallback: use the shift with updated timestamp
        final updatedShift = shift.copyWith(updatedAt: DateTime.now());
        return updatedShift;
      }
    } catch (e) {
      debugPrint('❌ Error updating shift via API: $e');
      rethrow;
    }
  }

  // Delete shift via API
  Future<void> _deleteShiftApi(int id) async {
    try {
      debugPrint('🗑️ Deleting shift via API (ID: $id)...');

      await ApiService.deleteShift(id);
      debugPrint('✅ Shift deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting shift via API: $e');
      rethrow;
    }
  }

  // Load shifts from API (with local storage fallback)
  Future<void> loadShifts() async {
    _setLoading(true);
    try {
      // Try to load from API first
      _shifts = await _loadShiftsFromApi();
      _error = null;

      // Save to local storage as cache
      await _saveShiftsToStorage();
    } catch (e) {
      debugPrint('⚠️ API failed, falling back to local storage: $e');

      // Fallback to local storage
      try {
        final prefs = await SharedPreferences.getInstance();
        final shiftsJson = prefs.getStringList(_shiftsKey) ?? [];

        _shifts = shiftsJson.map((jsonString) {
          final Map<String, dynamic> json = jsonDecode(jsonString);
          return Shift.fromJson(json);
        }).toList();

        _error = 'Using cached data - ${e.toString()}';
        debugPrint('✅ Loaded ${_shifts.length} shifts from local storage (fallback)');
      } catch (localError) {
        _error = 'Failed to load shifts: ${e.toString()}';
        debugPrint('❌ Error loading shifts from both API and local storage: $localError');
      }
    } finally {
      _setLoading(false);
    }
  }

  // Save shifts to local storage
  Future<void> _saveShiftsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shiftsJson = _shifts.map((shift) => jsonEncode(shift.toJson())).toList();
      await prefs.setStringList(_shiftsKey, shiftsJson);
      debugPrint('💾 Saved ${_shifts.length} shifts to local storage');
    } catch (e) {
      debugPrint('❌ Error saving shifts to storage: $e');
      throw e;
    }
  }

  // Create new shift (API first, local fallback)
  Future<bool> createShift(Shift shift) async {
    _setLoading(true);
    try {
      // Try to create via API first
      final createdShift = await _createShiftApi(shift);

      // Add to local list
      _shifts.add(createdShift);
      await _saveShiftsToStorage();

      _error = null;
      notifyListeners();
      debugPrint('✅ Created new shift via API: ${createdShift.name} (ID: ${createdShift.id})');
      return true;
    } catch (e) {
      debugPrint('⚠️ API creation failed, using local storage: $e');

      // Fallback to local storage
      try {
        final newId = _shifts.isEmpty ? 1 : _shifts.map((s) => s.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;

        final newShift = shift.copyWith(
          id: newId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        _shifts.add(newShift);
        await _saveShiftsToStorage();

        _error = 'Created locally - API sync failed: ${e.toString()}';
        notifyListeners();
        debugPrint('✅ Created new shift locally: ${newShift.name} (ID: ${newShift.id})');
        return true;
      } catch (localError) {
        _error = 'Failed to create shift: ${e.toString()}';
        debugPrint('❌ Error creating shift in both API and local storage: $localError');
        return false;
      }
    } finally {
      _setLoading(false);
    }
  }

  // Update existing shift (API first, local fallback)
  Future<bool> updateShift(int id, Shift updatedShift) async {
    _setLoading(true);
    try {
      // Try to update via API first
      final updatedShiftFromApi = await _updateShiftApi(id, updatedShift);

      // Update local list
      final index = _shifts.indexWhere((shift) => shift.id == id);
      if (index != -1) {
        _shifts[index] = updatedShiftFromApi;
        await _saveShiftsToStorage();
      }

      _error = null;
      notifyListeners();
      debugPrint('✅ Updated shift via API: ${updatedShiftFromApi.name} (ID: $id)');
      return true;
    } catch (e) {
      debugPrint('⚠️ API update failed, using local storage: $e');

      // Fallback to local storage
      try {
        final index = _shifts.indexWhere((shift) => shift.id == id);
        if (index == -1) {
          throw Exception('Shift with ID $id not found');
        }

        final shiftWithUpdate = updatedShift.copyWith(
          id: id,
          updatedAt: DateTime.now(),
        );

        _shifts[index] = shiftWithUpdate;
        await _saveShiftsToStorage();

        _error = 'Updated locally - API sync failed: ${e.toString()}';
        notifyListeners();
        debugPrint('✅ Updated shift locally: ${shiftWithUpdate.name} (ID: $id)');
        return true;
      } catch (localError) {
        _error = 'Failed to update shift: ${e.toString()}';
        debugPrint('❌ Error updating shift in both API and local storage: $localError');
        return false;
      }
    } finally {
      _setLoading(false);
    }
  }

  // Delete shift (API first, local fallback)
  Future<bool> deleteShift(int id) async {
    _setLoading(true);
    try {
      // Try to delete via API first
      await _deleteShiftApi(id);

      // Remove from local list
      final initialLength = _shifts.length;
      _shifts.removeWhere((shift) => shift.id == id);

      if (_shifts.length == initialLength) {
        debugPrint('⚠️ Shift not found in local list, but deleted from API');
      } else {
        await _saveShiftsToStorage();
      }

      _error = null;
      notifyListeners();
      debugPrint('✅ Deleted shift via API (ID: $id)');
      return true;
    } catch (e) {
      debugPrint('⚠️ API deletion failed, using local storage: $e');

      // Fallback to local storage
      try {
        final initialLength = _shifts.length;
        _shifts.removeWhere((shift) => shift.id == id);

        if (_shifts.length == initialLength) {
          throw Exception('Shift with ID $id not found');
        }

        await _saveShiftsToStorage();

        _error = 'Deleted locally - API sync failed: ${e.toString()}';
        notifyListeners();
        debugPrint('✅ Deleted shift locally (ID: $id)');
        return true;
      } catch (localError) {
        _error = 'Failed to delete shift: ${e.toString()}';
        debugPrint('❌ Error deleting shift from both API and local storage: $localError');
        return false;
      }
    } finally {
      _setLoading(false);
    }
  }

  // Get shift by ID
  Shift? getShiftById(int id) {
    try {
      return _shifts.firstWhere((shift) => shift.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear all shifts
  Future<void> clearAllShifts() async {
    _setLoading(true);
    try {
      _shifts.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_shiftsKey);

      _error = null;
      notifyListeners();
      debugPrint('✅ Cleared all shifts');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error clearing shifts: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Refresh shifts (alias for loadShifts)
  Future<void> refresh() async {
    await loadShifts();
  }
}
