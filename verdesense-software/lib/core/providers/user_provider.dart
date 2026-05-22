import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserProvider extends ChangeNotifier {
  User? _authUser;
  Map<String, dynamic>? _userData;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? _presenceSubscription;
  Timer? _heartbeatTimer;

  User? get authUser => _authUser;
  Map<String, dynamic>? get userData => _userData;
  
  bool get isAuthenticated => _authUser != null && _userData != null;

  String get id => _userData?['customId'] ?? 'Unknown ID';
  String get uid => _authUser?.uid ?? '';
  String get role => _userData?['role'] ?? 'Unknown';
  String get name => _userData?['name'] ?? 'Admin';
  String get firstName => name.isNotEmpty ? name.split(' ').first : 'Admin';
  String get username => _userData?['username'] ?? '';
  String get email => _userData?['email'] ?? '';
  String get phone => _userData?['phone'] ?? '';
  String get designation => _userData?['designation'] ?? 'Official Administrator';
  String get lastLogin => _userData?['lastLogin'] ?? '';
  String get lastIp => _userData?['lastIp'] ?? 'Unknown';
  String get department => _userData?['department'] ?? 'N/A';

  void setUser(User? user, Map<String, dynamic>? data) {
    _authUser = user;
    if (data != null) {
      // Create a clean modifiable string map from the dynamic Firebase snapshot
      _userData = Map<String, dynamic>.from(data);
      _setupPresence();
    } else {
      _userData = null;
      _cancelPresence();
    }
    notifyListeners();
  }

  void _setupPresence() {
    if (_authUser == null) return;
    
    // Cancel any existing subscription first
    _cancelPresence();

    final String userUid = _authUser!.uid;
    final presenceRef = _dbRef.child('users').child(userUid).child('isOnline');
    
    // Use Firebase RTDB presence system
    _presenceSubscription = _dbRef.child('.info/connected').onValue.listen((event) {
      if (event.snapshot.value == true) {
        // When connected, set isOnline to true
        presenceRef.set(true);
        // On disconnect, set isOnline to false
        presenceRef.onDisconnect().set(false);
        
        // Immediate heartbeat on connection
        _dbRef.child('users').child(userUid).update({
          'lastActive': ServerValue.timestamp,
        });
      }
    });

    // Start periodic heartbeat every 30 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_authUser != null) {
        _dbRef.child('users').child(_authUser!.uid).update({
          'lastActive': ServerValue.timestamp,
        });
      }
    });
  }

  void _cancelPresence() {
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void updateProfile(Map<String, dynamic> updatedData) {
    if (_userData != null) {
      _userData!.addAll(updatedData);
      notifyListeners();
    }
  }

  Future<void> clearUser() async {
    if (_authUser != null) {
      final String userUid = _authUser!.uid;
      // 1. Explicitly notify the server that we are going offline
      // We MUST await this to ensure other clients see the status change immediately.
      try {
        await _dbRef.child('users').child(userUid).update({
          'isOnline': false,
          'lastActive': ServerValue.timestamp,
        });
        debugPrint('[UserProvider] Explicit presence clear successful.');
      } catch (e) {
        debugPrint('[UserProvider] Explicit presence clear failed: $e');
      }

      // 2. Forcefully drop the websocket after the update is sent.
      // This ensures the update reaches the server before the connection is closed.
      FirebaseDatabase.instance.goOffline();
    }
    _cancelPresence();
    _authUser = null;
    _userData = null;
    notifyListeners();
  }
}


