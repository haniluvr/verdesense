import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/user_provider.dart';
import '../../auth/services/auth_service.dart';

import 'users_management_screen.dart';
import '../../../../core/providers/siren_provider.dart';

import '../../../../core/widgets/custom_notification_modal.dart';
import '../../../../core/widgets/siren_active_dialog.dart';
import '../../../../core/widgets/geometric_background.dart';
import '../../../../core/widgets/page_title.dart';
import '../../../../core/services/activity_log_service.dart';
import 'analytics_screen.dart';
import 'devices_screen.dart';
import 'map_screen.dart';
import 'override_siren_screen.dart';
import 'profile_menu_screen.dart';
import '../widgets/notifications_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late final List<ScrollController> _tabScrollControllers = List.generate(6, (index) => ScrollController()..addListener(_onScroll));
  bool _isScrolled = false;
  bool _isBottomNavVisible = true;
  int _currentIndex = 0;
  PageController? _pageController;
  PageController? _overridePageController;
  int _currentOverrideIndex = 0;
  bool _showNotificationsPanel = false;
  bool _isSirenDialogShowing = false;
  
  // --- Log State ---
  final int _hazardLevel = 0; // 0 = Nominal, 1 = Caution, 2 = Critical (Mock ESP32 data)
  Timer? _heartbeatTimer;

  // --- Firestore Logging State (transition tracking) ---
  final Map<String, Map<String, dynamic>> _prevHazardState = {};
  final Map<String, bool> _prevOnlineState = {};
  bool _sensorBaselineLoaded = false; // Skip logging on first snapshot
  final List<AppNotification> _notifications = [];
  final Set<String> _clearedNotificationIds = {};
  StreamSubscription? _urgentLogsSubscription;
  StreamSubscription? _clearedNotifsSubscription;
  String? _lastEvacuationLogId; // Firestore doc ID of last evacuation siren log

  int get _onlineCount => _deviceData.where((d) => d['isOnline'] == true).length;
  int get _offlineCount => _deviceData.where((d) => d['isOnline'] == false).length;

  // --- User Presence State ---
  StreamSubscription? _usersSubscription;


  int _serverTimeOffset = 0;
  StreamSubscription? _offsetSubscription;

  // --- FAB Pulse Animation ---
  late final AnimationController _fabPulseController;
  late final Animation<double> _fabPulseAnim;

  @override
  void initState() {
    super.initState();
    // WINDOWS SAFETY: The Firebase C++ RTDB SDK on Windows sends platform
    // channel messages on background threads. Opening multiple channels
    // simultaneously can overwhelm the engine and crash. We stagger each
    // operation with generous delays so each channel is fully initialized
    // before the next one starts.
    _staggeredInit();

    // FAB pulse — continuous repeating animation for the siren glow rings
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _fabPulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabPulseController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SirenProvider>().setBottomNavVisibility(true);
      }
    });



    _overridePageController = PageController(viewportFraction: 0.68);

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {
          _syncDeviceDataList();
        });
        _checkHourlyResets();
      }
    });
  }

  @override
  void dispose() {
    _fabPulseController.dispose();
    _heartbeatTimer?.cancel();
    _prototypeUnitsSubscription?.cancel();
    _sensorDataSubscription?.cancel();
    _usersSubscription?.cancel();
    _urgentLogsSubscription?.cancel();
    _clearedNotifsSubscription?.cancel();
    _offsetSubscription?.cancel();
    _pageController?.dispose();
    _overridePageController?.dispose();
    for (var controller in _tabScrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final currentController = _tabScrollControllers[_currentIndex];
    if (!currentController.hasClients) return;

    if (currentController.offset > 50 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (currentController.offset <= 50 && _isScrolled) {
      setState(() => _isScrolled = false);
    }

    if (currentController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isBottomNavVisible) {
        setState(() => _isBottomNavVisible = false);
        context.read<SirenProvider>().setBottomNavVisibility(false);
      }
    } else if (currentController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isBottomNavVisible) {
        setState(() => _isBottomNavVisible = true);
        context.read<SirenProvider>().setBottomNavVisibility(true);
      }
    }
  }

  Widget _buildTabScrollWrapper({required int index, required Widget child}) {
    return SingleChildScrollView(
      controller: _tabScrollControllers[index],
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 100,
            20,
            index == 2 ? 0 : 100),
        child: child,
      ),
    );
  }

  // Derived computed properties
  bool get _hasUrgentNotification =>
      _notifications.any((n) => n.isUrgent && !n.isResolved);

  bool get _hasAnyNotification =>
      _notifications.any((n) => (!n.isUrgent && !n.isRead) || (n.isUrgent && !n.isResolved));

  Future<void> _markAsClearedInDB(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseDatabase.instance.ref()
          .child('users')
          .child(user.uid)
          .child('clearedNotifications')
          .child(id)
          .set(true);
    } catch (e) {
      debugPrint('Failed to save cleared notification: $e');
    }
  }

  void _markAsRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) _notifications[index].isRead = true;
    });
    _markAsClearedInDB(id);
  }

  void _resolveUrgent(String id) {
    // Find the notification to check if it's a connectivity log
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final notif = _notifications[index];
      // If it's a connectivity offline notification, write shared resolution to Firestore
      if (notif.icon == Icons.wifi_off) {
        final userProvider = context.read<UserProvider>();
        final email = userProvider.email;
        ActivityLogService.markConnectivityResolved(docId: id, resolvedByEmail: email);
        // The Firestore stream will update the notification state for all users automatically
      } else {
        setState(() {
          _notifications[index].isResolved = true;
        });
        _markAsClearedInDB(id);
      }
    }
  }

  // --- Initialize Delayed Firestore Stream ---
  void _listenToClearedNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final dbRef = FirebaseDatabase.instance.ref().child('users').child(user.uid).child('clearedNotifications');
    _clearedNotifsSubscription = dbRef.onValue.listen((event) {
      if (!mounted) return;
      if (event.snapshot.value is Map) {
        final map = event.snapshot.value as Map;
        setState(() {
          _clearedNotificationIds.clear();
          _clearedNotificationIds.addAll(map.keys.map((k) => k.toString()));
          // Remove any already-fetched notifications that are cleared
          _notifications.removeWhere((n) => _clearedNotificationIds.contains(n.id));
        });
      } else {
         setState(() {
            _clearedNotificationIds.clear();
         });
      }
    });
  }

  void _listenToUrgentAlerts() {
    _urgentLogsSubscription = ActivityLogService.allLogs(limit: 20).snapshots().listen((snapshot) {
      if (!mounted) return;
      setState(() {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final priority = data['priority']?.toString() ?? 'INFO';
          
          // Only sync High/Critical/Warning alerts into the bell overlay
          if (priority != 'CRITICAL' && priority != 'WARNING') continue;
          
          // Double check it's not a generic user log
          final type = data['type']?.toString() ?? '';
          if (type == 'user') continue;

          final id = doc.id;
          if (_clearedNotificationIds.contains(id)) continue; // SKIP if already cleared by this user

          final isResolvedInDB = data['resolved'] as bool? ?? false;
          final resolvedByEmail = data['resolvedBy']?.toString();

          final existingIndex = _notifications.indexWhere((n) => n.id == id);

          if (existingIndex == -1) {
            // New alert detected
            final ts = data['timestamp'] as Timestamp?;
            final isUrgent = priority == 'CRITICAL';

            IconData icon = Icons.warning_amber_rounded;
            Color iconColor = AppColors.statusWarning;

            if (type == 'flame') { icon = Icons.local_fire_department; iconColor = AppColors.statusDanger; }
            else if (type == 'gas') { icon = Icons.smoking_rooms; iconColor = AppColors.statusDanger; }
            else if (type == 'siren') { icon = Icons.campaign; iconColor = AppColors.statusDanger; }
            else if (type == 'connectivity') { icon = Icons.wifi_off; iconColor = AppColors.statusWarning; }

            // Title formatting from message
            final message = data['message']?.toString() ?? 'Unknown Alert';
            final title = message.contains('at') ? message.split(' at ').first.replaceAll('💨', '').replaceAll('🌡️', '').trim() : 'System Alert';

            _notifications.insert(0, AppNotification(
              id: id,
              title: title,
              body: message,
              icon: icon,
              iconColor: iconColor,
              time: ts?.toDate() ?? DateTime.now(),
              isUrgent: isUrgent,
              isRead: false,
              isResolved: isResolvedInDB,
              resolvedBy: resolvedByEmail,
            ));
          } else {
            // Update resolution state if it changed (shared resolution from another user)
            final existing = _notifications[existingIndex];
            if (existing.isResolved != isResolvedInDB || existing.resolvedBy != resolvedByEmail) {
              _notifications[existingIndex] = AppNotification(
                id: existing.id,
                title: existing.title,
                body: existing.body,
                icon: existing.icon,
                iconColor: existing.iconColor,
                time: existing.time,
                isUrgent: existing.isUrgent,
                isRead: existing.isRead,
                isResolved: isResolvedInDB,
                resolvedBy: resolvedByEmail,
              );
            }
          }
        }
        
        // Sort newest first
        _notifications.sort((a, b) => b.time.compareTo(a.time));
        
        // Cap list size
        if (_notifications.length > 20) {
          _notifications.removeRange(20, _notifications.length);
        }
      });
    });
  }

  void _handleNotificationTap(String id) {
    // 1. Determine the target tab based on the notification type
    int targetTab = 3; // Default to Devices (index 3)
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final notif = _notifications[index];
      // Siren/hazard alerts go to Override Siren tab (index 2)
      if (notif.isUrgent || 
          notif.icon == Icons.local_fire_department || 
          notif.icon == Icons.smoking_rooms || 
          notif.icon == Icons.campaign) {
        targetTab = 2;
      }
    }

    // 2. Mark as read/cleared in DB
    _markAsRead(id);
    _resolveUrgent(id);

    setState(() {
      _currentIndex = targetTab; 
      _showNotificationsPanel = false;
      
      if (targetTab == 3) {
        _highlightedLogId = id;
        _highlightedItemKey = GlobalKey(); // Fresh key each tap
      } else {
        _highlightedLogId = null;
        _highlightedItemKey = null;
      }
    });

    // 3. Highlight/Scroll logic ONLY if going to Devices tab
    if (targetTab == 3) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        final keyContext = _highlightedItemKey?.currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        }
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            if (_highlightedLogId == id) {
              _highlightedLogId = null;
            }
          });
        }
      });
    }
  }

  String? _highlightedLogId;
  GlobalKey? _highlightedItemKey;

  // --- Device data ---
  final Map<String, Map<String, dynamic>> _deviceDataMap = {};
  List<Map<String, dynamic>> _deviceData = [];
  String _selectedLocation = "";
  StreamSubscription? _prototypeUnitsSubscription;
  StreamSubscription? _sensorDataSubscription;
  List<Set<String>> _syncGroups = [];

  void _staggeredInit() async {
    // Step 1: Wait for the UI transition to fully complete
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    // Step 2: Reconnect RTDB — this fires the C++ SDK's reconnection
    FirebaseDatabase.instance.goOnline();

    // Step 3: Wait for reconnection to settle before attaching listeners
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    // Listen to Server Time Offset
    _offsetSubscription = FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (event.snapshot.value is int) {
        _serverTimeOffset = event.snapshot.value as int;
      } else if (event.snapshot.value is num) {
        _serverTimeOffset = (event.snapshot.value as num).toInt();
      }
    });

    // Step 4: Attach prototype_units listener (channel 1)
    _listenToPrototypeUnits();

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Step 5: Attach sensor_data listener (channel 2)
    _listenToSensorData();

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Step 6: Attach users listener (channel 3)
    _listenToUserPresence();

    // Step 7: NOW it is safe to wake up Firestore for the login log.
    // All RTDB channels are fully established and idle.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userProv = context.read<UserProvider>();
      ActivityLogService.logUserLogin(
        email: user.email ?? '',
        username: userProv.username.isNotEmpty ? userProv.username : (user.email ?? 'Unknown'),
        role: userProv.role,
        platform: kIsWeb ? 'Web' : (Platform.isWindows ? 'Windows' : (Platform.isAndroid ? 'Android' : 'Other')),
      );
    }
    
    // Step 8: Initialize cleared notifications listener
    _listenToClearedNotifications();

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    // Step 9: Safely initialize the Urgent Notifications Firestore stream
    _listenToUrgentAlerts();
  }

  void _listenToPrototypeUnits() {
    final dbRef = FirebaseDatabase.instance.ref();
    _prototypeUnitsSubscription = dbRef.child('prototype_units').onValue.listen((event) {
      if (event.snapshot.value is Map) {
         final map = event.snapshot.value as Map;
         setState(() {
            // 1. CLEANUP: Remove devices from local state that no longer exist in prototype_units
            final currentKeys = map.keys.map((k) => k.toString()).toSet();
            _deviceDataMap.removeWhere((key, _) => !currentKeys.contains(key));

            // 2. UPDATE: Sync existing/new devices
            map.forEach((key, val) {
               final mac = key.toString();
               final data = val as Map;
               _deviceDataMap.putIfAbsent(mac, () => {});
               _deviceDataMap[mac]!['location'] = data['name']?.toString() ?? 'Unknown';
               
               int priority = 999;
               if (data.containsKey('priority')) {
                   priority = data['priority'] is int ? data['priority'] : int.tryParse(data['priority'].toString()) ?? 999;
               } else if (data.containsKey('config') && data['config'] is Map && data['config'].containsKey('priority')) {
                   final c = data['config'] as Map;
                   priority = c['priority'] is int ? c['priority'] : int.tryParse(c['priority'].toString()) ?? 999;
               }
               _deviceDataMap[mac]!['priority'] = priority;
               
               bool includeInHeadcount = true;
               if (data.containsKey('config') && data['config'] is Map && data['config'].containsKey('include_in_headcount')) {
                   includeInHeadcount = data['config']['include_in_headcount'] == true;
               }
               _deviceDataMap[mac]!['include_in_headcount'] = includeInHeadcount;

               String? syncMac;
               if (data.containsKey('config') && data['config'] is Map && data['config'].containsKey('sync_mac')) {
                   syncMac = data['config']['sync_mac']?.toString();
               }
               _deviceDataMap[mac]!['sync_mac'] = syncMac;
            });
            _syncDeviceDataList();
         });
      } else {
        setState(() {
          _deviceDataMap.clear();
          _syncDeviceDataList();
        });
      }
    });
  }

  void _listenToSensorData() {
    final dbRef = FirebaseDatabase.instance.ref();
    _sensorDataSubscription = dbRef.child('sensor_data').onValue.listen((event) {
      if (event.snapshot.value is Map) {
         final map = event.snapshot.value as Map;
         setState(() {
            // 1. CLEANUP: Only keep sensor data for devices that exist in the primary source (prototype_units)
            // But usually we can just sync what we receive. 
            // If prototype_units listener is running, it will handle the final cleanup.
            
            map.forEach((key, val) {
               final mac = key.toString();
               final data = val as Map;
               // Only update if it exists in our master map to avoid orphaned sensor data
               if (!_deviceDataMap.containsKey(mac)) return;

               _deviceDataMap[mac]!['mac'] = mac;
               _deviceDataMap[mac]!['count'] = data['people_inside'] ?? 0;
               _deviceDataMap[mac]!['entries'] = data['people_inside'] ?? 0;
               _deviceDataMap[mac]!['exits'] = data['total_exits'] ?? 0;
               _deviceDataMap[mac]!['last_updated'] = data['last_updated'];
               _deviceDataMap[mac]!['last_reset_hour'] = data['last_reset_hour'];
               _deviceDataMap[mac]!['device_status'] = data['device_status'];
               _deviceDataMap[mac]!['power_status'] = data['power_status'];
               _deviceDataMap[mac]!['temperature'] = data['temperature'] ?? 0.0;
               _deviceDataMap[mac]!['gas'] = data['gas'] ?? 0;

               // --- Hazard state transition logging ---
               final location = _deviceDataMap[mac]?['location'] ?? 'Unknown';

               // Map actual RTDB field names written by the hardware:
               //   main_flame  → bool (false = flame detected with active-LOW sensor)
               //   backup_flame → int  (analog ADC; detected when value <= flameThreshold)
               //   gas         → int  (analog ADC; detected when value >= gasThreshold default 500)
               //   siren_alert_active → bool (evacuation siren)
               final bool curFlame = data['main_flame'] == false ||
                   (data['backup_flame'] != null &&
                       (data['backup_flame'] as num) <= 2000);
               final bool curGas =
                   (data['gas'] as num? ?? 0) >= 500;
               final bool curSiren = data['siren_alert_active'] == true;

               _deviceDataMap[mac]!['isDanger'] = curFlame || curGas || curSiren;

               // Only log transitions AFTER the first snapshot baseline is set
               if (_sensorBaselineLoaded) {
                 final prevHazard = _prevHazardState[mac] ?? {};
                 final bool prevFlame = prevHazard['flame_detected'] == true;
                 if (curFlame && !prevFlame) {
                   Future.microtask(() => ActivityLogService.logFlameDetected(
                     deviceMAC: mac, location: location,
                     sensorType: 'backup_analog',
                     rawValue: (data['backup_flame'] as num?)?.toInt(),
                   ));
                 } else if (!curFlame && prevFlame) {
                   Future.microtask(() => ActivityLogService.logFlameCleared(deviceMAC: mac, location: location));
                 }

                 final bool prevGas = prevHazard['gas_detected'] == true;
                 if (curGas && !prevGas) {
                   Future.microtask(() => ActivityLogService.logGasDetected(
                     deviceMAC: mac, location: location,
                     rawValue: (data['gas'] as num?)?.toInt() ?? 0,
                   ));
                 } else if (!curGas && prevGas) {
                   Future.microtask(() => ActivityLogService.logGasCleared(deviceMAC: mac, location: location));
                 }

                 final bool prevSiren = prevHazard['siren_active'] == true;
                 if (curSiren && !prevSiren) {
                   Future.microtask(() => ActivityLogService.logSirenActivated(
                     deviceMAC: mac, location: location,
                     flameValue: (data['backup_flame'] as num?)?.toInt() ?? 0,
                     gasValue: (data['gas'] as num?)?.toInt() ?? 0,
                   ));
                 } else if (!curSiren && prevSiren) {
                   Future.microtask(() => ActivityLogService.logSirenDeactivated(deviceMAC: mac, location: location));
                 }
               }

               // Save current state for next comparison
               _prevHazardState[mac] = {
                 'flame_detected': curFlame,
                 'gas_detected': curGas,
                 'siren_active': curSiren,
               };
            });
            _sensorBaselineLoaded = true; // Future snapshots will trigger transition logs
            _syncDeviceDataList();
         });

         // --- Remote siren state sync (runs OUTSIDE setState) ---
         // Aggregate siren flags across ALL devices to detect ESP32 auto-triggers
         bool anyAlertActive = false;
         bool anyClearActive = false;
         map.forEach((key, val) {
           final mac = key.toString();
           if (!_deviceDataMap.containsKey(mac)) return;
           final data = val as Map;
           if (data['siren_alert_active'] == true) anyAlertActive = true;
           if (data['siren_clear_active'] == true) anyClearActive = true;
         });

         if (!mounted) return;
         final sirenProvider = context.read<SirenProvider>();

         if (anyAlertActive && sirenProvider.activeSirenTitle != "EVACUATION SIREN") {
           // ESP32 auto-triggered evacuation siren — show in app
           sirenProvider.activateSirenFromRemote(
             "EVACUATION SIREN",
             Icons.warning_amber_rounded,
             AppColors.statusDanger,
           );

           if (!_isSirenDialogShowing) {
             _isSirenDialogShowing = true;
             Future.microtask(() async {
               if (mounted) {
                 await SirenActiveDialog.show(context, sirenProvider);
                 if (mounted) {
                   setState(() {
                     _isSirenDialogShowing = false;
                   });
                 }
               } else {
                 _isSirenDialogShowing = false;
               }
             });
           }
         } else if (!anyAlertActive && sirenProvider.activeSirenTitle == "EVACUATION SIREN") {
           // Evacuation siren deactivated remotely (ESP32 timeout or clear) — sync UI
           sirenProvider.deactivateSirenFromRemote();

           if (_isSirenDialogShowing && mounted) {
             Navigator.of(context, rootNavigator: true).pop();
             _isSirenDialogShowing = false;
           }
         }

         // --- Safety Alert remote sync (Issue #6 fix) ---
         // ESP32 auto-transitions from evacuation → safety alert:
         // sync the Safety Alert banner to the app UI without writing back to Firebase.
         if (anyClearActive && sirenProvider.activeSirenTitle != "SAFETY ALERT") {
           sirenProvider.activateSirenFromRemote(
             "SAFETY ALERT",
             Icons.health_and_safety_rounded,
             AppColors.statusWarning,
           );

           if (!_isSirenDialogShowing) {
             _isSirenDialogShowing = true;
             Future.microtask(() async {
               if (mounted) {
                 await SirenActiveDialog.show(context, sirenProvider);
                 if (mounted) {
                   setState(() {
                     _isSirenDialogShowing = false;
                   });
                 }
               } else {
                 _isSirenDialogShowing = false;
               }
             });
           }
         } else if (!anyClearActive && sirenProvider.activeSirenTitle == "SAFETY ALERT") {
           // Safety alert cleared remotely
           sirenProvider.deactivateSirenFromRemote();

           if (_isSirenDialogShowing && mounted) {
             Navigator.of(context, rootNavigator: true).pop();
             _isSirenDialogShowing = false;
           }
         }
      }
    });
  }


  void _listenToUserPresence() {
    final dbRef = FirebaseDatabase.instance.ref();
    _usersSubscription = dbRef.child('users').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final Map<dynamic, dynamic> usersMap = event.snapshot.value as Map<dynamic, dynamic>;
        int admins = 0;
        int facilitators = 0;

        usersMap.forEach((key, value) {
          if (value is Map) {
            final bool isOnline = value['isOnline'] == true || value['isOnline'] == 1;
            final String role = (value['role']?.toString() ?? '').toLowerCase();
            final int lastActive = value['lastActive'] is int ? value['lastActive'] : 0;
            
            // Liveness check: Only count as online if isOnline is true 
            // AND they've been active in the last 1 minute (60,000 ms).
            // This handles cases where the user closed the app without logging out.
            final bool isLive = isOnline && (DateTime.now().millisecondsSinceEpoch - lastActive < 60000);

            if (isLive) {
              if (role == 'admin') {
                admins++;
              } else if (role == 'facilitator') {
                facilitators++;
              }
            }
          }
        });

        if (mounted) {
          setState(() {
            // Intentionally empty: Variables were removed because they were never used elsewhere.
          });
        }
      } else {
        // Handle null or invalid data
        if (mounted) {
          setState(() {
            // Intentionally empty.
          });
        }
      }
    });
  }


  void _syncDeviceDataList() {
    _deviceData = _deviceDataMap.values.map((v) {
        // Use explicit device_status and last_updated from sensor_data as the heartbeat indicator.
        bool isLive = false;
        String connState = "NEVER SEEN";
        final lastUpdated = v['last_updated'];
        final ds = v['device_status'];
        final explicitDeviceFalse = ds == false || ds == "false";

        if (!explicitDeviceFalse && lastUpdated != null) {
            final ts = DateTime.fromMillisecondsSinceEpoch(
              (lastUpdated is int) ? lastUpdated : (lastUpdated as num).toInt(),
            );
            final estimatedServerTime = DateTime.now().add(Duration(milliseconds: _serverTimeOffset));
            isLive = estimatedServerTime.difference(ts).inSeconds.abs() < 360; // 360s timeout (heartbeat is 300s)
        }
        connState = isLive ? "ONLINE" : "OFFLINE";

        // --- Connectivity transition logging ---
        // Only log transitions AFTER the sensor baseline is established to
        // avoid false online/offline flaps during the staggered init phase.
        final mac = (v['mac'] ?? '').toString();
        final location = (v['location'] ?? 'Unknown Node').toString();
        if (_sensorBaselineLoaded && mac.isNotEmpty && _prevOnlineState.containsKey(mac)) {
          final wasOnline = _prevOnlineState[mac]!;
          if (isLive && !wasOnline) {
            Future.microtask(() => ActivityLogService.logDeviceCameOnline(
              deviceMAC: mac, location: location, lastUpdated: lastUpdated ?? DateTime.now().millisecondsSinceEpoch
            ));
          } else if (!isLive && wasOnline) {
            Future.microtask(() => ActivityLogService.logDeviceWentOffline(
              deviceMAC: mac, location: location, lastUpdated: lastUpdated ?? DateTime.now().millisecondsSinceEpoch
            ));
          }
        }
        if (mac.isNotEmpty) _prevOnlineState[mac] = isLive;

        return {
           'location': v['location'] ?? 'Unknown Node',
           'mac': mac,
           'count': v['count'] ?? 0,
           'entries': (v['count'] ?? 0) + (v['exits'] ?? 0),
           'exits': v['exits'] ?? 0,
           'isOnline': isLive,
           'connectionState': connState,
           'last_updated': v['last_updated'],
           'last_reset_hour': v['last_reset_hour'],
           'priority': v['priority'] ?? 999,
           'include_in_headcount': v['include_in_headcount'] ?? true,
           'power_status': v['power_status'],
           'temperature': v['temperature'] ?? 0.0,
           'gas': v['gas'] ?? 0,
           'isDanger': v['isDanger'] == true,
        };
    }).toList();

    // --- Connected Components for Sync Groups ---
    final Map<String, Set<String>> adj = {};
    for (final mac in _deviceDataMap.keys) {
      final String? syncMac = _deviceDataMap[mac]?['sync_mac'];
      if (syncMac != null && _deviceDataMap.containsKey(syncMac)) {
        adj.putIfAbsent(mac, () => {}).add(syncMac);
        adj.putIfAbsent(syncMac, () => {}).add(mac);
      }
    }
    
    final Set<String> visited = {};
    _syncGroups = [];
    for (final mac in _deviceDataMap.keys) {
      if (!visited.contains(mac) && adj.containsKey(mac)) {
        final Set<String> group = {};
        final List<String> stack = [mac];
        while (stack.isNotEmpty) {
          final m = stack.removeLast();
          if (!visited.contains(m)) {
            visited.add(m);
            group.add(m);
            stack.addAll(adj[m] ?? []);
          }
        }
        _syncGroups.add(group);
      }
    }

    // Calculate totals for each group
    final Map<String, int> macToGroupTotal = {};
    for (final group in _syncGroups) {
      int total = 0;
      for (final mac in group) {
        total += (_deviceDataMap[mac]?['count'] ?? 0) as int;
      }
      for (final mac in group) {
        macToGroupTotal[mac] = total;
      }
    }

    // Update synced devices with their group total
    _deviceData = _deviceData.map((d) {
      final mac = d['mac'];
      if (macToGroupTotal.containsKey(mac)) {
        final totalCount = macToGroupTotal[mac]!;
        // Calculate group total exits for correct gross entries in synced groups
        int groupExits = 0;
        final group = _syncGroups.firstWhere((g) => g.contains(mac));
        for (final m in group) {
          groupExits += (_deviceDataMap[m]?['exits'] ?? 0) as int;
        }

        return {
          ...d,
          'count': totalCount,
          'entries': totalCount + groupExits, 
        };
      }
      return d;
    }).toList();
    
    _deviceData.sort((a, b) {
       final pA = a['priority'] as int;
       final pB = b['priority'] as int;
       return pA.compareTo(pB);
    });

    
    if (_deviceData.isNotEmpty && _selectedLocation.isEmpty) {
       _selectedLocation = _deviceData.first['location'];
    }

    if (_deviceData.isNotEmpty && _pageController == null) {
       final int realIndex = _deviceData.indexWhere((data) => data['location'] == _selectedLocation);
       _pageController = PageController(
         initialPage: 1000 * _deviceData.length + (realIndex != -1 ? realIndex : 0),
       );
    }

    // Keep SirenProvider in sync with known device MAC keys
    final macKeys = _deviceDataMap.keys.toList();
    if (macKeys.isNotEmpty) {
      context.read<SirenProvider>().setDeviceKeys(macKeys);
    }
  }

  // --- Automated Hourly Reset Logic ---
  bool _isResettingCounts = false;

  void _checkHourlyResets() async {
    if (_isResettingCounts) return;
    final currentHour = DateTime.now().hour;
    final dbRef = FirebaseDatabase.instance.ref();
    
    for (final device in _deviceData) {
      final bool isOnline = device['isOnline'] == true;
      if (!isOnline) continue;

      final mac = device['mac']?.toString() ?? '';
      if (mac.isEmpty) continue;

      final lastResetHour = (device['last_reset_hour'] as num?)?.toInt();
      if (lastResetHour == currentHour) continue;

      // This device is online and hasn't been reset this hour yet
      _isResettingCounts = true;
      try {
        // Log the count snapshot BEFORE resetting
        final exits = (device['exits'] as num?)?.toInt() ?? 0;
        final entries = (device['entries'] as num?)?.toInt() ?? 0;
        final location = device['location']?.toString() ?? 'Unknown';
        if (exits > 0 || entries > 0) {
          Future.microtask(() => ActivityLogService.logHourlySnapshot(
            deviceMAC: mac,
            location: location,
            entriesThisHour: entries,
            exitsThisHour: exits,
            resetHour: currentHour,
          ));
        }

        await dbRef.child('sensor_data').child(mac).update({
          'total_exits': 0,
          'last_reset_hour': currentHour,
        });
      } catch (_) {
        // Silently handle write failures
      }
      _isResettingCounts = false;
    }
  }

  Future<void> _resetSingleDevice(String mac, String location) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final currentHour = DateTime.now().hour;
    try {
      // Log the snapshot BEFORE resetting
      final deviceEntry = _deviceData.where((d) => d['mac']?.toString() == mac).firstOrNull;
      final exits = (deviceEntry?['exits'] as num?)?.toInt() ?? 0;
      final entries = (deviceEntry?['entries'] as num?)?.toInt() ?? 0;
      if (exits > 0 || entries > 0) {
        Future.microtask(() => ActivityLogService.logHourlySnapshot(
          deviceMAC: mac,
          location: location,
          entriesThisHour: entries,
          exitsThisHour: exits,
          resetHour: currentHour,
        ));
      }

      await dbRef.child('sensor_data').child(mac).update({
        'total_exits': 0,
        'last_reset_hour': currentHour,
      });
      if (mounted) {
        CustomNotificationModal.show(
          context: context,
          title: "Count Reset",
          message: "Counts for '$location' have been reset to 0.",
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationModal.show(
          context: context,
          title: "Reset Failed",
          message: "Could not reset counts for '$location'.",
          isSuccess: false,
        );
      }
    }
  }

  // Computed total across all sensors (respecting include_in_headcount)
  int get _totalHeadcount {
    int sum = 0;
    final Set<String> processedMacs = {};
    
    // 1. Process Grouped Devices (Linked)
    for (final group in _syncGroups) {
      bool includeGroup = false;
      int groupSum = 0;
      for (final mac in group) {
        final d = _deviceDataMap[mac];
        if (d != null) {
          if (d['include_in_headcount'] == true) includeGroup = true;
          groupSum += (d['count'] ?? 0) as int;
        }
        processedMacs.add(mac);
      }
      if (includeGroup) sum += groupSum;
    }
    
    // 2. Process Independent Devices (Ungrouped)
    for (final d in _deviceData) {
      final String mac = d['mac']?.toString() ?? '';
      if (!processedMacs.contains(mac)) {
        if (d['include_in_headcount'] == true) {
          sum += (d['count'] as int).clamp(0, 99999);
        }
      }
    }
    return sum;
  }
    
  int get _totalExits => _deviceData
    .where((d) => d['include_in_headcount'] == true)
    .fold(0, (acc, d) => acc + ((d['exits'] as num?)?.toInt() ?? 0));
    
  int get _totalPeopleInside => _totalHeadcount;

  // New getter: Total Entries (Headcount + Exits)
  int get _liveTotalEntries => _totalHeadcount + _totalExits;

  String _getScreenTitle(int index) {
    switch (index) {
      case 0: return "Dashboard";
      case 1: return "Map";
      case 2: return "Override Siren";
      case 3: return "Devices";
      case 4: return "Analytics";
      case 5: return "Profile";
      default: return "Dashboard";
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 80,
        titleSpacing: 24,
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentIndex == 0 ? "VerdeSense" : _getScreenTitle(_currentIndex),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (_currentIndex == 0) ...[
                const SizedBox(height: 3),
                Text(
                  "Greenhouse Monitoring System",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
        backgroundColor: _isScrolled
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.8)
            : Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: _isScrolled
            ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              )
            : null,
        titleTextStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 28),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0, top: 16.0),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white.withValues(alpha: 0.05) 
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Notification Bell ---
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _hasAnyNotification,
                      smallSize: 9,
                      backgroundColor: _hasUrgentNotification
                          ? AppColors.statusDanger
                          : AppColors.statusWarning,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          key: ValueKey(_hasUrgentNotification),
                          _hasUrgentNotification
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          color: _hasUrgentNotification
                              ? AppColors.statusDanger
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _showNotificationsPanel = !_showNotificationsPanel;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // --- Main body ---
          GeometricBackground(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                // Index 0: Dashboard Content
                _buildTabScrollWrapper(
                  index: 0,
                  child: _buildNewHomeTab(),
                ),
                // Index 1: Map
                MapScreen(deviceData: _deviceData, activeIndex: _currentIndex),
                // Index 2: Override Siren
                _buildTabScrollWrapper(
                  index: 2,
                  child: OverrideSirenScreen(activeIndex: _currentIndex),
                ),
                // Index 3: Devices
                _buildTabScrollWrapper(
                  index: 3,
                  child: DevicesScreen(
                    highlightedLogId: _highlightedLogId,
                    highlightedItemKey: _highlightedItemKey,
                    parentScrollController: _tabScrollControllers[3],
                    onlineCount: _onlineCount,
                    offlineCount: _offlineCount,
                    activeIndex: _currentIndex,
                    deviceData: _deviceData,
                    serverTimeOffset: _serverTimeOffset,
                  ),
                ),
                // Index 4: Analytics
                _buildTabScrollWrapper(
                  index: 4,
                  child: AnalyticsScreen(activeIndex: _currentIndex),
                ),
                // Index 5: Profile
                ProfileMenuScreen(onNavigate: (index) => setState(() => _currentIndex = index)),
              ],
            ),
          ),

          // --- Notification Panel Overlay ---
          if (_showNotificationsPanel)
            Positioned.fill(
              top: 0,
              child: NotificationsPanel(
                notifications: _notifications,
                onClose: () => setState(() => _showNotificationsPanel = false),
                onMarkAsRead: (id) {
                  _markAsRead(id);
                  // Auto-close if no more standard notifications
                  final remaining = _notifications
                      .where((n) => !n.isUrgent && !n.isRead)
                      .length;
                  if (remaining == 0 && !_hasUrgentNotification) {
                    setState(() => _showNotificationsPanel = false);
                  }
                },
                onNotificationTap: _handleNotificationTap,
                onResolveUrgent: (id) => _resolveUrgent(id),
              ),
            ),

          // --- Fixed Floating Siren Button ---
          // Sits above the bottom nav bar (nav bar total height ≈ 96dp incl padding)
          Positioned(
            bottom: 104,
            right: 20,
            child: _buildFloatingSirenFab(),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 1.5),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 8),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // ── Liquid Glass Nav Pill ──────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      width: double.infinity,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.surfaceDark.withValues(alpha: 0.75)
                            : Colors.white.withValues(alpha: 0.80),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.white.withValues(alpha: 0.60),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                            spreadRadius: -4,
                          ),
                          BoxShadow(
                            color: AppColors.primaryRose.withValues(alpha: 0.08),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 6 slots
                          const int slots = 6;
                          final slotWidth = constraints.maxWidth / slots;
                          final double slot = _currentIndex.toDouble();
                          return Stack(
                            children: [
                              // ── Animated sliding highlight pill ──────────────
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOutCubic,
                                left: slotWidth * slot + 6,
                                top: 8,
                                bottom: 8,
                                width: slotWidth - 12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    color: AppColors.primaryRose.withValues(alpha: 0.22),
                                    border: Border.all(
                                      color: AppColors.primaryRose.withValues(alpha: 0.40),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryRose.withValues(alpha: 0.18),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // ── Nav Items Row ──────────────────────────────────
                              Positioned.fill(
                                child: Row(
                                  children: [
                                    _buildNavItem(icon: Icons.dashboard_rounded, label: "Dashboard", index: 0),
                                    _buildNavItem(icon: Icons.map_rounded, label: "Map", index: 1),
                                    _buildNavItem(icon: Icons.campaign_rounded, label: "Siren", index: 2),
                                    _buildNavItem(icon: Icons.devices_rounded, label: "Devices", index: 3),
                                    _buildNavItem(icon: Icons.analytics_rounded, label: "Analytics", index: 4),
                                    _buildNavItem(icon: Icons.person_rounded, label: "Profile", index: 5),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.primaryRose;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.40);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
            _showNotificationsPanel = false;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: isSelected ? 1.0 : 0.75,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : inactiveColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.2,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingSirenFab() {
    final sirenProvider = context.watch<SirenProvider>();
    final isActive = sirenProvider.isSirenActive;
    final isOnSirenTab = _currentIndex == 2;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fabColor = isActive
        ? AppColors.statusDanger
        : AppColors.primaryRose;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      // Hide the FAB when the bottom nav itself is hidden (user scrolling down)
      offset: _isBottomNavVisible ? Offset.zero : const Offset(0, 3),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1.15),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, pulseScale, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing glow rings — only when a siren is active
              if (isActive)
                ...List.generate(3, (i) {
                  final delay = i / 3;
                  final rawVal = ((pulseScale - 0.85) / 0.30 - delay) % 1.0;
                  final val = rawVal < 0 ? rawVal + 1.0 : rawVal;
                  return Transform.scale(
                    scale: 1.0 + val * 1.4,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fabColor.withValues(alpha: (1.0 - val) * 0.22),
                      ),
                    ),
                  );
                }),
              // The FAB itself
              GestureDetector(
                onTap: () {
                  if (isActive) {
                    SirenActiveDialog.show(context, sirenProvider);
                  } else {
                    setState(() {
                      _currentIndex = 2; // Override Siren tab
                      _showNotificationsPanel = false;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? fabColor
                        : (isDark
                            ? AppColors.surfaceDark
                            : Colors.white),
                    border: Border.all(
                      color: isOnSirenTab && !isActive
                          ? fabColor.withValues(alpha: 0.70)
                          : fabColor.withValues(alpha: isActive ? 0.0 : 0.45),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: fabColor.withValues(
                            alpha: isActive ? 0.45 : 0.20),
                        blurRadius: isActive ? 24 : 12,
                        spreadRadius: isActive ? 4 : 0,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      key: ValueKey(isActive),
                      isActive
                          ? Icons.power_settings_new_rounded
                          : Icons.campaign_rounded,
                      color: isActive
                          ? Colors.white
                          : fabColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color hazardColor;
    IconData hazardIcon;
    String hazardLabel;
    bool isPulsing = false;

    // Simulated dynamic hazard logic dependent on ESP32 Firebase inputs
    switch (_hazardLevel) {
      case 2:
        hazardColor = const Color(0xFFFF5252);
        hazardIcon = Icons.error_outline;
        hazardLabel = "CRITICAL ALERT";
        isPulsing = true;
        break;
      case 1:
        hazardColor = Colors.amber;
        hazardIcon = Icons.warning_amber;
        hazardLabel = "CAUTION";
        break;
      case 0:
      default:
        hazardColor = const Color(0xFF00B0FF);
        hazardIcon = Icons.health_and_safety;
        hazardLabel = "SYSTEM NORMAL";
        break;
    }

    // Styled system-notification badge for the Hazard card
    final hazardBadge = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5), // Reduced padding
          decoration: BoxDecoration(
            color: hazardColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hazardColor.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start, // Align dot to the top of multi-line text
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2), // Nudge dot down slightly for alignment
                child: _PulsingDot(color: hazardColor),
              ),
              const SizedBox(width: 4), 
              Flexible(
                child: Text(
                  hazardLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: hazardColor,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                  maxLines: 2, // Allow 2 lines
                  overflow: TextOverflow.ellipsis,
                  softWrap: true, // Enable wrapping
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "SYS ALERT",
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: hazardColor.withValues(alpha: 0.55),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );

    // ── Card 1: Headcount value widget ──────────────────────────────────────
    const headcountColor = Color(0xFF00C853);
    final headcountBadge = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _totalPeopleInside.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'REAL-TIME SYNC',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: headcountColor,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );

    // ── Card 1.5: Total Entries value widget ────────────────────────────────
    const entriesColor = Color(0xFFFF9100); // Vibrant Orange/Amber
    final entriesBadge = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _liveTotalEntries.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'NO DEDUCTIONS',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: entriesColor,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );

    // ── Card 2: Exits value widget ────────────────────────────────────────
    const exitsColor = Color(0xFFFF5252);
    final exitsBadge = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _totalExits.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'RESETS HOURLY',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: exitsColor,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildGlassStatCard(
              title: "Live Total\nHeadcount",
              value: '',
              icon: Icons.groups,
              color: headcountColor,
              isDark: isDark,
              valueWidget: headcountBadge,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildGlassStatCard(
              title: "Live Total\nEntries",
              value: '',
              icon: Icons.person_add_rounded,
              color: entriesColor,
              isDark: isDark,
              valueWidget: entriesBadge,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildGlassStatCard(
              title: "Current Hour\nExits",
              value: '',
              icon: Icons.directions_run,
              color: exitsColor,
              isDark: isDark,
              valueWidget: exitsBadge,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildGlassStatCard(
              title: "Hazard Status",
              value: '',
              icon: hazardIcon,
              color: hazardColor,
              isDark: isDark,
              isPulsing: isPulsing,
              valueWidget: hazardBadge,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewHomeTab() {

    final sirenProvider = context.watch<SirenProvider>();
    final isAlertActive = sirenProvider.isSirenActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: isAlertActive
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF29161A), Color(0xFF1A0B0E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: isAlertActive ? const Color(0xFF2A161A) : null,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isAlertActive 
                  ? AppColors.statusDanger.withValues(alpha: 0.3)
                  : const Color(0xFF4A2B33),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Watermark
                Positioned(
                  right: -50,
                  top: -70,
                  child: Icon(
                    isAlertActive ? Icons.shield_rounded : Icons.verified_user_rounded,
                    size: 250,
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Column(
                    children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isAlertActive 
                          ? AppColors.statusDanger.withValues(alpha: 0.15)
                          : AppColors.primaryRose.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAlertActive ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                      color: isAlertActive ? AppColors.statusDanger : AppColors.primaryRose,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAlertActive ? "ALERT" : "SAFE",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAlertActive 
                      ? "Fire detected in Main Warehouse"
                      : "All systems operating normally",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isAlertActive) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentIndex = 1; // Map tab
                          });
                        },
                        icon: const Icon(Icons.location_on, color: Colors.white, size: 16),
                        label: const Text(
                          "View on Map",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusDanger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 16),

        // Metrics Grid
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A161A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF4A2B33)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.people_alt_outlined, color: Colors.white.withValues(alpha: 0.5), size: 20),
                        ),
                        Text(
                          "Tracker", 
                          style: TextStyle(
                            color: AppColors.primaryRose.withValues(alpha: 0.8), 
                            fontSize: 14, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _totalPeopleInside.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "People inside",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A161A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF4A2B33)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRose.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.notifications_active_outlined, color: AppColors.primaryRose.withValues(alpha: 0.8), size: 20),
                        ),
                        Text(
                          "Siren", 
                          style: TextStyle(
                            color: AppColors.primaryRose.withValues(alpha: 0.8), 
                            fontSize: 14, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      isAlertActive ? "Active" : "Armed",
                      style: TextStyle(
                        color: isAlertActive ? AppColors.statusDanger : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAlertActive ? "Sounding now" : "Loud Alarm",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A161A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF4A2B33)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.water_drop_outlined, color: Colors.white.withValues(alpha: 0.5), size: 20),
                        ),
                        Text(
                          "Water", 
                          style: TextStyle(
                            color: AppColors.primaryRose.withValues(alpha: 0.8), 
                            fontSize: 14, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "Normal",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Irrigation level",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A161A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF4A2B33)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.thermostat_outlined, color: Colors.white.withValues(alpha: 0.5), size: 20),
                        ),
                        Text(
                          "Temperature", 
                          style: TextStyle(
                            color: AppColors.primaryRose.withValues(alpha: 0.8), 
                            fontSize: 14, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "24°C",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Optimal range",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Active Sensors Header
        Row(
          children: [
            Icon(Icons.monitor_heart_outlined, color: AppColors.primaryRose.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: 8),
            const Text(
              "Active Sensors",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Active Sensors List Wrapper
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A161A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF4A2B33)),
          ),
          child: Column(
            children: [
              _buildActiveSensorTile(
                name: "Main Warehouse",
                status: "Offline",
                isOnline: false,
                isFirst: true,
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              _buildActiveSensorTile(
                name: "Greenhouse Alpha",
                status: "Online",
                isOnline: true,
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
              _buildActiveSensorTile(
                name: "Entrance Gate",
                status: "Online",
                isOnline: true,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildActiveSensorTile({required String name, required String status, required bool isOnline, bool isFirst = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.primaryRose.withValues(alpha: 0.5) : AppColors.statusDanger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Smoke Sensor",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF361D21),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: isOnline ? AppColors.primaryRose.withValues(alpha: 0.5) : AppColors.statusDanger,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSirenCommandStrip() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color hazardColor;
    String hazardLabel;
    bool isPulsing = false;

    switch (_hazardLevel) {
      case 2:
        hazardColor = AppColors.statusDanger;
        hazardLabel = "CRITICAL ALERT";
        isPulsing = true;
        break;
      case 1:
        hazardColor = AppColors.statusWarning;
        hazardLabel = "CAUTION";
        break;
      default:
        hazardColor = AppColors.primaryBlue;
        hazardLabel = "SYSTEM NORMAL";
        break;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          height: 90,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              // Zone 1: Vital Population
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _PulsingDot(color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "LIVE POPULATION",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _totalPeopleInside.toString(),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Zone 2: Status Bay
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "HAZARD STATUS",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSirenStatusCapsule(hazardLabel, hazardColor, isPulsing),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSirenStatusCapsule(String label, Color color, bool pulsing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          if (pulsing)
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing) ...[
            _PulsingDot(color: color),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    bool isPulsing = false,
    bool isTextSmall = false,
    Widget? valueWidget,
  }) {
    final bool isNarrow = MediaQuery.of(context).size.width < 400;
    Widget cardChild = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 6 : 10, 
        vertical: isNarrow ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Use the custom valueWidget (e.g. badge) if provided, else plain text
          valueWidget ?? Text(
            value,
            style: TextStyle(
              fontSize: isTextSmall ? 13 : 24,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    final glassWrapper = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: cardChild,
      ),
    );

    if (isPulsing) {
      return _PulsingWrapper(color: color, child: glassWrapper);
    }
    return glassWrapper;
  }

  Widget _buildCompactStat({required IconData icon, required int value, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTallyStatChip({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularOverrideCarousel() {
    final List<Map<String, dynamic>> overrides = [
      {
        'title': "EVACUATION SIREN",
        'subtitle': "Trigger all building sirens immediately",
        'icon': Icons.campaign_rounded,
        'color': AppColors.statusDanger,
        'isReset': false,
      },
      {
        'title': "SAFETY ALERT",
        'subtitle': "Activate blue visual strobe for advisory signalling",
        'icon': Icons.light_mode_rounded,
        'color': AppColors.primaryBlue,
        'isReset': false,
      },
      {
        'title': "RESET ALL ALARMS",
        'subtitle': "Cancel all active sirens and visual alerts",
        'icon': Icons.refresh_rounded,
        'color': AppColors.statusSafe,
        'isReset': true,
      },
    ];

    return Column(
      children: [
        SizedBox(
          height: 450,
          child: PageView.builder(
            controller: _overridePageController,
            onPageChanged: (index) => setState(() => _currentOverrideIndex = index),
            itemCount: overrides.length,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final item = overrides[index];
              final isSelected = _currentOverrideIndex == index;
              
              return AnimatedScale(
                scale: isSelected ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _TacticalDialButton(
                  title: item['title'],
                  subtitle: item['subtitle'],
                  icon: item['icon'],
                  color: item['color'],
                  isReset: item['isReset'],
                  isSelected: isSelected,
                  onTapNavigate: () {
                    _overridePageController?.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  onTrigger: () {
                    if (!mounted) return;
                    
                    // If this siren is already active, skip confirmation and show control dialog
                    final sirenProvider = context.read<SirenProvider>();
                    if (sirenProvider.activeSirenTitle == item['title'] && !item['isReset']) {
                      SirenActiveDialog.show(context, sirenProvider);
                      return;
                    }

                    const actionText = "ACTIVATE";
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF2A161A) : Colors.white,
                          elevation: 20,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: item['color'].withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          title: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item['color'].withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.security_rounded, color: item['color'], size: 32),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "COMMAND AUTHORIZATION",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 18, 
                                  letterSpacing: 2.0,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "SECURITY PROTOCOL REQUIRED",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: item['color'],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Are you sure you want to $actionText the\n'${item['title']}'?\n\nThis command will be logged and executed immediately across all active zones.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14, 
                                  height: 1.5,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          actionsAlignment: MainAxisAlignment.center,
                          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          actions: [
                            (() {
                              bool isHovered = false;
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return MouseRegion(
                                    onEnter: (_) => setState(() => isHovered = true),
                                    onExit: (_) => setState(() => isHovered = false),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: isHovered 
                                            ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)) 
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isHovered 
                                              ? (isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2))
                                              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                                          width: 1,
                                        ),
                                      ),
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          overlayColor: isDark ? Colors.white10 : Colors.black12,
                                        ),
                                        child: Text(
                                          "ABORT", 
                                          style: TextStyle(
                                            color: isHovered 
                                                ? (isDark ? Colors.white70 : Colors.black87)
                                                : (isDark ? Colors.white38 : Colors.grey[600]), 
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            })(),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                if (!item['isReset']) {
                                  Navigator.pop(context);
                                  context.read<SirenProvider>().activateSiren(item['title'], item['icon'], item['color']);
                                  // Log evacuation siren manual trigger and store doc ID
                                  if (item['title'] == 'EVACUATION SIREN') {
                                    final userProv = context.read<UserProvider>();
                                    ActivityLogService.logEvacuationSirenTriggered(
                                      triggeredByName: userProv.name,
                                      triggeredByRole: userProv.role,
                                      triggeredByEmail: userProv.email,
                                    ).then((docId) {
                                      if (mounted) setState(() => _lastEvacuationLogId = docId);
                                    });
                                  }
                                  SirenActiveDialog.show(
                                    context,
                                    context.read<SirenProvider>(),
                                    onTerminate: () {
                                      // Always call — uses docId fast-path or fallback query if null
                                      ActivityLogService.markEvacuationSirenDeactivated(
                                        docId: _lastEvacuationLogId,
                                      );
                                      if (mounted) setState(() => _lastEvacuationLogId = null);
                                    },
                                  );
                                } else {
                                  // If the active siren is EVACUATION SIREN, mark the log as Deactivated
                                  final sirenTitle = context.read<SirenProvider>().activeSirenTitle;
                                  context.read<SirenProvider>().terminateSiren();
                                  if (sirenTitle == 'EVACUATION SIREN') {
                                    // Always call — uses docId fast-path or fallback query if null
                                    ActivityLogService.markEvacuationSirenDeactivated(
                                      docId: _lastEvacuationLogId,
                                    );
                                    if (mounted) setState(() => _lastEvacuationLogId = null);
                                  }
                                  CustomNotificationModal.showToast(
                                    context: context,
                                    title: "System Reset",
                                    message: "${item['title']} has been successfully DEACTIVATED.",
                                    color: item['color'],
                                    icon: item['icon'],
                                  );
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: item['color'],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                elevation: 8,
                                shadowColor: item['color'].withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                actionText, 
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900, 
                                  letterSpacing: 1.5,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(overrides.length, (index) {
            final isSelected = _currentOverrideIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 4,
              width: isSelected ? 20 : 8,
              decoration: BoxDecoration(
                color: isSelected 
                    ? overrides[index]['color'] 
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCrowdCountList() {
    if (_deviceData.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "CROWD MONITORING",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showCrowdCountDetail(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
                      ),
                      child: Icon(Icons.north_east_rounded,
                          color: colorScheme.onSurfaceVariant, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text("LOCATION",
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.8,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                  ),
                  Expanded(
                    child: Text("ENTRY",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.8,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                  ),
                  Expanded(
                    child: Text("EXIT",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.8,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06), height: 1),
              const SizedBox(height: 12),
              ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _deviceData.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = _deviceData[index];
                  final int entries = ((data['count'] ?? 0) as num).toInt().clamp(0, 99999);
                  final int exits = ((data['exits'] ?? 0) as num).toInt();
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(data['location'],
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      Expanded(
                        child: Text(entries.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            )),
                      ),
                      Expanded(
                        child: Text(exits.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            )),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCrowdCountDetail() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final nextReset = DateTime(now.year, now.month, now.day, now.hour + 1);
    final minsUntilReset = nextReset.difference(now).inMinutes;

    // Check if any device is online (reset is only active when devices are online)
    final bool anyOnline = _deviceData.any((d) => d['isOnline'] == true);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (dialogContext) {
        return TweenAnimationBuilder(
          duration: const Duration(milliseconds: 350),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, double animValue, child) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0 * animValue, sigmaY: 8.0 * animValue),
              child: Opacity(
                opacity: animValue.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.85 + (0.15 * animValue),
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.78,
                        maxWidth: 500,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: isDark ? 0.92 : 0.97),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Header ──────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.groups_rounded, color: AppColors.primaryBlue, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Crowd Count Details",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${_deviceData.length} sensor${_deviceData.length == 1 ? '' : 's'} registered",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant, size: 22),
                                  style: IconButton.styleFrom(
                                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Auto-Reset Timer Banner ─────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: anyOnline
                                      ? [AppColors.statusWarning.withValues(alpha: 0.10), AppColors.statusWarning.withValues(alpha: 0.04)]
                                      : [colorScheme.onSurfaceVariant.withValues(alpha: 0.06), colorScheme.onSurfaceVariant.withValues(alpha: 0.02)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: anyOnline
                                      ? AppColors.statusWarning.withValues(alpha: 0.25)
                                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: (anyOnline ? AppColors.statusWarning : colorScheme.onSurfaceVariant).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.timer_outlined,
                                      color: anyOnline ? AppColors.statusWarning : colorScheme.onSurfaceVariant,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          anyOnline
                                              ? "Next auto-reset in ${minsUntilReset}m"
                                              : "Auto-reset paused",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: anyOnline ? AppColors.statusWarning : colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          anyOnline
                                              ? "Counts reset at the top of every hour"
                                              : "No devices online — reset will resume on connection",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // ── Column Headers ──────────────────────
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text("LOCATION", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.0, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text("ENTRY", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.0, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text("EXIT", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.0, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))),
                                ),
                                const SizedBox(width: 36), // Space for reset button
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Divider(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06), height: 20),
                          ),

                          // ── Device Rows ─────────────────────────
                          Flexible(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              shrinkWrap: true,
                              itemCount: _deviceData.length,
                              itemBuilder: (context, index) {
                                final data = _deviceData[index];
                                final int rawEntries = ((data['count'] ?? 0) as num).toInt().clamp(0, 99999);
                                final int rawExits = ((data['exits'] ?? 0) as num).toInt();
                                final bool isOnline = data['isOnline'] == true;
                                final String mac = data['mac']?.toString() ?? '';
                                final String location = data['location']?.toString() ?? 'Unknown';

                                String updatedText = "\u2014";
                                final lu = data['last_updated'];
                                if (lu != null) {
                                  final ts = DateTime.fromMillisecondsSinceEpoch((lu is int) ? lu : (lu as num).toInt());
                                  final diff = now.difference(ts);
                                  if (diff.inSeconds < 60) {
                                    updatedText = "Just now";
                                  } else if (diff.inMinutes < 60) {
                                    updatedText = "${diff.inMinutes}m ago";
                                  } else if (diff.inHours < 24) {
                                    updatedText = "${diff.inHours}h ago";
                                  } else {
                                    updatedText = "${diff.inDays}d ago";
                                  }
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // Main data row
                                        Row(
                                          children: [
                                            // Location + Status
                                            Expanded(
                                              flex: 5,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    location,
                                                    style: TextStyle(
                                                      color: colorScheme.onSurface,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: isOnline ? AppColors.statusSafe : AppColors.statusDanger,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: (isOnline ? AppColors.statusSafe : AppColors.statusDanger).withValues(alpha: 0.5),
                                                              blurRadius: 4,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        isOnline ? "Online" : "Offline",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: isOnline ? AppColors.statusSafe : AppColors.statusDanger,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        "· $updatedText",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Entry count (people_inside)
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                children: [
                                                  Text(
                                                    rawEntries.toString(),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: AppColors.statusSafe,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Exit count
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                children: [
                                                  Text(
                                                    rawExits.toString(),
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: AppColors.statusDanger,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Per-location reset button
                                            SizedBox(
                                              width: 36,
                                              child: IconButton(
                                                onPressed: mac.isEmpty ? null : () {
                                                  showDialog(
                                                    context: dialogContext,
                                                    barrierDismissible: true,
                                                    builder: (ctx) => AlertDialog(
                                                      backgroundColor: colorScheme.surface,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                      title: Row(
                                                        children: [
                                                          Icon(Icons.restart_alt_rounded, color: AppColors.statusWarning, size: 24),
                                                          const SizedBox(width: 10),
                                                          Expanded(
                                                            child: Text("Reset $location?", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                                          ),
                                                        ],
                                                      ),
                                                      content: Text(
                                                        "This will reset entries, exits, and people inside to 0 for '$location'.\n\nThis action cannot be undone.",
                                                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, height: 1.5),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx),
                                                          child: Text("Cancel", style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed: () {
                                                            Navigator.pop(ctx);
                                                            Navigator.pop(dialogContext);
                                                            _resetSingleDevice(mac, location);
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: AppColors.statusWarning,
                                                            foregroundColor: Colors.white,
                                                            elevation: 0,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                          ),
                                                          child: const Text("RESET", style: TextStyle(fontWeight: FontWeight.bold)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.restart_alt_rounded,
                                                  size: 18,
                                                  color: AppColors.statusWarning,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // ── Reset All Button ────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: dialogContext,
                                    barrierDismissible: true,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: colorScheme.surface,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, color: AppColors.statusDanger, size: 28),
                                          const SizedBox(width: 12),
                                          const Text("Reset All Counts", style: TextStyle(fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      content: Text(
                                        "This will reset entries, exits, and people inside to 0 for ALL devices.\n\nThis action cannot be undone.",
                                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14, height: 1.5),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text("Cancel", style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            Navigator.pop(dialogContext);
                                            final dbRef = FirebaseDatabase.instance.ref();
                                            final currentHour = DateTime.now().hour;
                                            for (final device in _deviceData) {
                                              final mac = device['mac']?.toString() ?? '';
                                              if (mac.isNotEmpty) {
                                                await dbRef.child('sensor_data').child(mac).update({
                                                  'total_exits': 0,
                                                  'people_inside': 0,
                                                  'last_reset_hour': currentHour,
                                                  'reset_counts': true,
                                                });
                                              }
                                            }
                                            if (mounted) {
                                              CustomNotificationModal.show(
                                                context: this.context,
                                                title: "Counts Reset",
                                                message: "All ToF counts have been reset to 0.",
                                                isSuccess: true,
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.statusDanger,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          child: const Text("RESET ALL", style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                                label: const Text("Reset All ToF Counts", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.statusDanger.withValues(alpha: 0.08),
                                  foregroundColor: AppColors.statusDanger,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: AppColors.statusDanger.withValues(alpha: 0.2)),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoleCard(BuildContext context, String label, int count, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label.toUpperCase().split(' ').first, // Just the role name
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  _PulsingDot(color: color),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "$count",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "ONLINE",
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: color.withValues(alpha: 0.7),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowUsersButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UsersManagementScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.manage_accounts_rounded, color: AppColors.primaryBlue, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "USER RECORDS",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.primaryBlue.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Manage Active Roles",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primaryBlue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TacticalDialButton extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isReset;
  final bool isSelected;
  final VoidCallback onTrigger;
  final VoidCallback onTapNavigate;

  const _TacticalDialButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isReset,
    required this.isSelected,
    required this.onTrigger,
    required this.onTapNavigate,
  });

  @override
  State<_TacticalDialButton> createState() => _TacticalDialButtonState();
}

class _TacticalDialButtonState extends State<_TacticalDialButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.contain,
          child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () async {
            if (widget.isSelected) {
              // Forced 'long-press' animation sequence on tap
              setState(() => _isPressed = true);
              await Future.delayed(const Duration(milliseconds: 150));
              if (mounted) setState(() => _isPressed = false);
              widget.onTrigger();
            } else {
              widget.onTapNavigate();
            }
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.94 : (widget.isSelected ? 1.0 : 0.8),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: widget.isSelected ? (0.3 + (_isPressed ? 0.2 : 0)) : 0.05),
                    blurRadius: _isPressed ? 70 : 50,
                    spreadRadius: _isPressed ? 12 : 8,
                  ),
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.5) : widget.color.withValues(alpha: 0.1),
                    offset: Offset(_isPressed ? 6 : 14, _isPressed ? 6 : 14),
                    blurRadius: _isPressed ? 15 : 28,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Ring
                  Container(
                    width: 330,
                    height: 330,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                          (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                          (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: widget.isSelected 
                            ? widget.color.withValues(alpha: 0.6) 
                            : (isDark ? Colors.white10 : Colors.black12),
                        width: 3.5,
                      ),
                      boxShadow: [
                        if (widget.isSelected)
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.3),
                            blurRadius: 25,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                  ),
                  // Machined Inner Border / Rim
                  Container(
                    width: 298,
                    height: 298,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isDark ? Colors.white24 : Colors.black12),
                        width: 1.0,
                      ),
                    ),
                  ),
                  // Inner Button Surface
                  Container(
                    width: 290,
                    height: 290,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF2A161A) : Colors.white,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark 
                          ? [
                              _isPressed ? const Color(0xFF1A0B0E) : const Color(0xFF2A161A), 
                              _isPressed ? const Color(0xFF100508) : const Color(0xFF1A0B0E)
                            ]
                          : [Colors.white, const Color(0xFFE2E8F0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: _isPressed ? 0.4 : 0.3),
                          offset: Offset(_isPressed ? 2 : 6, _isPressed ? 2 : 6),
                          blurRadius: _isPressed ? 5 : 15,
                        ),
                        if (widget.isSelected)
                          BoxShadow(
                            color: widget.color.withValues(alpha: _isPressed ? 0.7 : 0.5),
                            blurRadius: _isPressed ? 50 : 40,
                            spreadRadius: _isPressed ? 10 : 5,
                          ),
                        // Subtle inner glow
                        BoxShadow(
                          color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.4),
                          offset: const Offset(-2, -2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.icon,
                          size: 84,
                          color: widget.isSelected ? widget.color : (isDark ? Colors.white24 : Colors.grey[400]),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: widget.isSelected ? widget.color : (isDark ? Colors.white24 : Colors.grey[400]),
                            letterSpacing: 1.0,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: widget.isSelected 
                                ? (isDark ? Colors.white.withValues(alpha: 0.75) : widget.color.withValues(alpha: 0.9))
                                : (isDark ? Colors.white10 : Colors.grey[300]),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// _AnimatedNavBarPainter is no longer used — replaced by the Liquid Glass nav bar.
// Kept as a stub to avoid removing the class entirely in case it's referenced elsewhere.
class _AnimatedNavBarPainter extends CustomPainter {
  final BuildContext context;
  final double alertsAnimationValue;
  _AnimatedNavBarPainter(this.context, this.alertsAnimationValue);

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulsingWrapper extends StatefulWidget {
  final Widget child;
  final Color color;
  const _PulsingWrapper({required this.child, required this.color});

  @override
  State<_PulsingWrapper> createState() => _PulsingWrapperState();
}

class _PulsingWrapperState extends State<_PulsingWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _anim.value * 0.4),
                blurRadius: 16 * _anim.value,
                spreadRadius: 2 * _anim.value,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

