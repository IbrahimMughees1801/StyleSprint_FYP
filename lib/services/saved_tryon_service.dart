import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/saved_tryon.dart';
import 'virtual_tryon_service.dart';

class SavedTryOnService extends ChangeNotifier {
  SavedTryOnService._();

  static final SavedTryOnService instance = SavedTryOnService._();

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _tryOnService = VirtualTryOnService();
  final List<SavedTryOn> _items = [];
  final Set<String> _pollingSessions = {};

  String? _loadedUid;
  String? _latestCompletedSessionId;

  List<SavedTryOn> get items => List.unmodifiable(_items);
  int get processingCount => _items.where((item) => item.isProcessing).length;
  int get completedCount => _items.where((item) => item.isCompleted).length;

  Future<void> load() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (_loadedUid != null || _items.isNotEmpty) {
        _loadedUid = null;
        _items.clear();
      }
      notifyListeners();
      return;
    }

    if (_loadedUid == user.uid) return;
    _loadedUid = user.uid;

    try {
      final snapshot = await _collection(user.uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 8));

      _items
        ..clear()
        ..addAll(snapshot.docs.map((doc) => SavedTryOn.fromMap(doc.data())));
      _sortItems();
      notifyListeners();

      for (final item in _items.where((item) => item.isProcessing)) {
        startPolling(item.sessionId);
      }
    } catch (_) {
      notifyListeners();
    }
  }

  Future<void> addProcessingTryOn({
    required String sessionId,
    required String productName,
    String? productImageUrl,
  }) async {
    final item = SavedTryOn(
      sessionId: sessionId,
      productName: productName,
      productImageUrl: productImageUrl,
      status: 'processing',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    _upsert(item);
    notifyListeners();
    await _save(item);
    startPolling(sessionId);
  }

  void startPolling(String sessionId) {
    if (_pollingSessions.contains(sessionId)) return;
    _pollingSessions.add(sessionId);
    unawaited(_pollUntilFinished(sessionId));
  }

  String? consumeLatestCompletedSessionId() {
    final sessionId = _latestCompletedSessionId;
    _latestCompletedSessionId = null;
    return sessionId;
  }

  Future<void> deleteTryOn(String sessionId) async {
    _items.removeWhere((item) => item.sessionId == sessionId);
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _collection(user.uid).doc(sessionId).delete();
    } catch (_) {
      // Local removal is enough for the current demo session.
    }
  }

  Future<void> _pollUntilFinished(String sessionId) async {
    const maxAttempts = 300;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final status = await _tryOnService.checkStatus(sessionId);

        if (status.isCompleted) {
          final imageBytes = await _tryOnService.getResultImage(sessionId);
          await _markCompleted(sessionId, base64Encode(imageBytes));
          _pollingSessions.remove(sessionId);
          return;
        }

        if (status.isFailed) {
          await _markFailed(sessionId, 'Processing failed');
          _pollingSessions.remove(sessionId);
          return;
        }
      } catch (_) {
        // The tunnel/backend can briefly be unavailable; keep polling.
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    await _markFailed(sessionId, 'Processing timed out');
    _pollingSessions.remove(sessionId);
  }

  Future<void> _markCompleted(
    String sessionId,
    String resultImageBase64,
  ) async {
    final item = _find(sessionId);
    if (item == null) return;

    final updated = item.copyWith(
      status: 'completed',
      completedAt: DateTime.now().millisecondsSinceEpoch,
      resultImageBase64: resultImageBase64,
      error: '',
    );
    _upsert(updated);
    _latestCompletedSessionId = sessionId;
    notifyListeners();
    await _save(updated);
  }

  Future<void> _markFailed(String sessionId, String error) async {
    final item = _find(sessionId);
    if (item == null) return;

    final updated = item.copyWith(
      status: 'failed',
      completedAt: DateTime.now().millisecondsSinceEpoch,
      error: error,
    );
    _upsert(updated);
    notifyListeners();
    await _save(updated);
  }

  Future<void> _save(SavedTryOn item) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _collection(user.uid)
          .doc(item.sessionId)
          .set(item.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Keep the in-memory copy even if cloud sync is slow.
    }
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('saved_tryons');
  }

  SavedTryOn? _find(String sessionId) {
    for (final item in _items) {
      if (item.sessionId == sessionId) return item;
    }
    return null;
  }

  void _upsert(SavedTryOn item) {
    final index = _items.indexWhere(
      (saved) => saved.sessionId == item.sessionId,
    );
    if (index >= 0) {
      _items[index] = item;
    } else {
      _items.insert(0, item);
    }
    _sortItems();
  }

  void _sortItems() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
