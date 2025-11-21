import 'package:flutter/material.dart';
import 'dart:async';

class RefreshNotifier extends ChangeNotifier {
  static final RefreshNotifier _instance = RefreshNotifier._internal();
  
  factory RefreshNotifier() => _instance;
  
  RefreshNotifier._internal();
  
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  
  void refreshAccounts() {
    _debounceNotification();
  }
  
  void refreshTransactions() {
    _debounceNotification();
  }
  
  void refreshAll() {
    _debounceNotification();
  }
  
  void _debounceNotification() {
    // Cancel any existing timer
    _debounceTimer?.cancel();
    
    // Start a new timer
    _debounceTimer = Timer(_debounceDelay, () {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }
  
  // Force immediate notification without debouncing
  void notifyImmediately() {
    _debounceTimer?.cancel();
    if (hasListeners) {
      notifyListeners();
    }
  }
  
  // Add a static method to access the instance directly
  static RefreshNotifier get instance => _instance;
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}