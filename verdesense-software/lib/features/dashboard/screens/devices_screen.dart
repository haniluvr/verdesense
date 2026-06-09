import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Added for date formatting later
import 'package:provider/provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/activity_log_service.dart';
import '../widgets/device_management_modal.dart';

class DeviceLog {
  final String id;
  final IconData icon;
  final String title;
  final String message;
  final DateTime dateTime;
  final Color iconColor;
  bool isUnread;
  final String sensorType;   // friendly display label e.g. 'People Counter (ToF)'
  final String logTypeRaw;   // raw Firestore 'type' e.g. 'tof', 'user', 'connectivity'
  final String logEvent;     // Firestore 'event' field e.g. 'login', 'device_offline'
  final String priority;     // 'High', 'Mid', 'Low'
  String currentStatus;
  final bool? sirenActivated;
  final String specificZone;
  final String? powerStatus;

  // Per-type visibility flags
  final bool showPriority;
  final bool showStatus;
  final bool showLocation;

  // User log extras
  final String? role;
  final String? platform;
  final String? userEmail; // user's email for user-type logs

  // Manual evacuation siren extras
  final String? triggeredBy;       // display name of user who triggered
  final String? triggeredByRole;   // role of that user
  final String? triggeredByEmail;  // email of that user

  // Connectivity resolution
  final bool isResolvable;   // true only for connectivity-offline logs
  final bool isResolved;
  final String? resolvedBy;

  DeviceLog({
    required this.id,
    required this.icon,
    required this.title,
    required this.message,
    required this.dateTime,
    required this.iconColor,
    required this.isUnread,
    required this.sensorType,
    required this.logTypeRaw,
    required this.logEvent,
    required this.priority,
    this.currentStatus = 'Active',
    this.sirenActivated,
    required this.specificZone,
    this.powerStatus,
    this.showPriority = true,
    this.showStatus = true,
    this.showLocation = true,
    this.role,
    this.platform,
    this.userEmail,
    this.triggeredBy,
    this.triggeredByRole,
    this.triggeredByEmail,
    this.isResolvable = false,
    this.isResolved = false,
    this.resolvedBy,
  });
}

class DevicesScreen extends StatefulWidget {
  final String? highlightedLogId;
  final GlobalKey? highlightedItemKey;
  final ScrollController? parentScrollController;
  final int onlineCount;
  final int offlineCount;
  final int activeIndex;
  final List<Map<String, dynamic>> deviceData;
  final int serverTimeOffset;

  const DevicesScreen({
    super.key,
    this.highlightedLogId,
    this.highlightedItemKey,
    this.parentScrollController,
    this.onlineCount = 0,
    this.offlineCount = 0,
    this.activeIndex = 3,
    this.deviceData = const [],
    this.serverTimeOffset = 0,
  });

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  // Filter State
  DateTime? selectedFilterDate;
  List<String> selectedSensorTypes = [];
  List<String> excludedSensorTypes = [];
  List<String> selectedPriorities = [];

  // Firestore-backed log list
  List<DeviceLog> _firestoreLogs = [];
  bool _isLoadingLogs = true;

  // Pagination State
  int _currentPage = 1;
  int? _explicitLogsPerPage; // null = default (10)

  @override
  void initState() {
    super.initState();
    // WINDOWS SAFETY: The Firebase C++ SDK on Windows crashes if multiple
    // data channels open concurrently on background threads during login.
    // Instead of initializing immediately, we ONLY start the Firestore stream
    // when the user actually switches to the Devices tab (index 3).
    if (widget.activeIndex == 3) {
      _listenToFirestoreLogs();
    }
  }

  @override
  void didUpdateWidget(DevicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex == 3 && oldWidget.activeIndex != 3) {
      // User just navigated to this tab
      if (_isLoadingLogs && _firestoreLogs.isEmpty) {
        _listenToFirestoreLogs();
      }
    }
  }

  void _listenToFirestoreLogs() {
    FirebaseFirestore.instance
        .collection('activity_logs')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _firestoreLogs = snapshot.docs.map(_mapDocToDeviceLog).toList();
        _isLoadingLogs = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _isLoadingLogs = false);
    });
  }

  DeviceLog _mapDocToDeviceLog(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final type = data['type']?.toString() ?? '';
    final priority = data['priority']?.toString() ?? 'INFO';
    final event = data['event']?.toString() ?? '';
    final ts = data['timestamp'] as Timestamp?;

    IconData icon;
    Color iconColor;
    String sensorLabel;   // friendly display name
    bool showPriority = true;
    bool showStatus = true;
    bool showLocation = true;

    switch (type) {
      case 'flame':
        icon = Icons.local_fire_department;
        iconColor = AppColors.statusDanger;
        sensorLabel = 'Flame Detector';
        break;
      case 'gas':
        icon = Icons.smoking_rooms;
        iconColor = AppColors.statusDanger;
        sensorLabel = 'Smoke / Gas Detector';
        break;
      case 'temperature':
        icon = Icons.thermostat;
        iconColor = AppColors.statusWarning;
        sensorLabel = 'Temperature Sensor';
        break;
      case 'siren':
        icon = Icons.campaign_rounded;
        iconColor = AppColors.statusDanger;
        sensorLabel = 'Emergency Siren';
        if (event == 'evacuation_siren_manual') showStatus = false;
        break;
      case 'tof':
        icon = Icons.people_alt_rounded;
        iconColor = Colors.cyanAccent;
        sensorLabel = 'People Counter (ToF)';
        showStatus = false; // No status for snapshot logs
        break;
      case 'connectivity':
        icon = event == 'device_online' ? Icons.wifi_rounded : Icons.wifi_off_rounded;
        iconColor = event == 'device_online' ? AppColors.statusSafe : AppColors.statusWarning;
        sensorLabel = 'Network / Gateway';
        break;
      case 'power':
        icon = Icons.battery_alert_rounded;
        iconColor = AppColors.statusWarning;
        sensorLabel = 'UPS / Power Monitor';
        break;
      case 'user':
        icon = Icons.person_rounded;
        iconColor = Colors.cyanAccent;
        final userEvent = event;
        if (userEvent == 'login' || userEvent == 'logout') {
          sensorLabel = 'User Activity';
        } else {
          sensorLabel = 'Device Management';
        }
        showStatus = false;
        showLocation = false;
        break;
      default:
        icon = Icons.info_outline;
        iconColor = Colors.grey;
        sensorLabel = 'System';
    }

    // Priority label
    String priorityLabel;
    switch (priority) {
      case 'CRITICAL':
        priorityLabel = 'High';
        break;
      case 'WARNING':
        priorityLabel = 'Mid';
        break;
      default:
        priorityLabel = 'Low';
    }

    // Status logic
    bool? sirenActivated;
    String status;
    if (type == 'connectivity' && event == 'device_offline') {
      final resolved = data['resolved'] as bool? ?? false;
      status = resolved ? 'Resolved' : 'Unresolved';
    } else if (type == 'flame' || type == 'gas' || type == 'siren') {
      sirenActivated = event.contains('activated') || event.contains('alert') || event == 'evacuation_siren_manual';
      // For manual evacuation siren logs, read the live sirenStatus from Firestore
      // so it updates to 'Deactivated' when the siren is terminated.
      if (event == 'evacuation_siren_manual' && data['sirenStatus'] != null) {
        status = data['sirenStatus'].toString(); // 'Active' or 'Deactivated'
      } else {
        status = priority == 'CRITICAL' ? 'Active' : 'Resolved';
      }
    } else {
      status = priority == 'CRITICAL' ? 'Active' : 'Resolved';
    }

    // Connectivity resolution data
    final isOfflineConnectivity = type == 'connectivity' && event == 'device_offline';
    // If the 'resolved' field is absent (legacy log), treat it as resolved.
    // Only newly-written logs have resolved: false explicitly set.
    final isResolved = data['resolved'] as bool? ?? true;
    final resolvedBy = data['resolvedBy']?.toString();

    // Title formatting
    final location = data['location']?.toString() ?? data['deviceMAC']?.toString() ?? 'System';
    String title;
    switch (type) {
      case 'user':
        title = sensorLabel; // 'User Activity' or 'Device Management'
        break;
      case 'tof':
        title = 'People Counter – $location';
        break;
      case 'connectivity':
        title = 'Connectivity – $location';
        break;
      default:
        title = '$sensorLabel – $location';
    }

    return DeviceLog(
      id: doc.id,
      icon: icon,
      title: title,
      message: data['message']?.toString() ?? '',
      dateTime: ts?.toDate() ?? DateTime.now(),
      iconColor: iconColor,
      isUnread: false,
      sensorType: sensorLabel,
      logTypeRaw: type,
      logEvent: event,
      priority: priorityLabel,
      currentStatus: status,
      sirenActivated: sirenActivated,
      specificZone: location,
      powerStatus: data['newLevel']?.toString(),
      showPriority: showPriority,
      showStatus: showStatus,
      showLocation: showLocation,
      role: data['role']?.toString(),
      platform: data['platform']?.toString(),
      userEmail: data['email']?.toString(),
      triggeredBy: data['triggeredByName']?.toString(),
      triggeredByRole: data['triggeredByRole']?.toString(),
      triggeredByEmail: data['triggeredByEmail']?.toString(),
      isResolvable: isOfflineConnectivity,
      isResolved: isResolved,
      resolvedBy: resolvedBy,
    );
  }


  String _getPowerSummary() {
    if (widget.deviceData.isEmpty) return "No Devices Linked";
    
    final onlineDevices = widget.deviceData.where((d) => d['isOnline'] == true).toList();
    if (onlineDevices.isEmpty) return "Unknown (All Offline)";

    // Priority: Low > Adequate > High
    bool hasLow = false;
    bool hasAdequate = false;
    bool hasHigh = false;

    for (var device in onlineDevices) {
      final status = (device['power_status']?.toString() ?? 'Unknown').toLowerCase();
      if (status == 'low') {
        hasLow = true;
      } else if (status == 'adequate') {
        hasAdequate = true;
      } else if (status == 'high') {
        hasHigh = true;
      }
    }

    if (hasLow) return "Action Required: Low Power";
    if (hasAdequate) return "Systems Adequate";
    if (hasHigh) return "All Systems Nominal";
    return "Status Unknown";
  }

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final isAdmin = userProv.role.toLowerCase() == 'admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const DeviceManagementModal(),
                );
              },
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryRose,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Online / Offline count
        Row(
          children: [
            Expanded(
              child: _GlowingStatusCard(title: "Online Devices", count: widget.onlineCount, color: AppColors.statusSafe),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlowingStatusCard(title: "Offline Devices", count: widget.offlineCount, color: AppColors.statusDanger),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDevicesList(),
        const SizedBox(height: 16),

        Row(
          children: [
            // Power Management Card
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: InkWell(
                    onTap: () => _showDeviceDetailsModal(context, "Power Management"),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 140,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.statusSafe.withValues(alpha: 0.15),
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
                                  color: AppColors.statusSafe.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.bolt_rounded, color: AppColors.statusSafe, size: 14),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "POWER",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: isAdmin
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "UPS & AC",
                                  textAlign: isAdmin
                                      ? TextAlign.start
                                      : TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getPowerSummary(),
                                  textAlign: isAdmin
                                      ? TextAlign.start
                                      : TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w600,
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
            ),
            if (isAdmin) ...[
              const SizedBox(width: 12),
              // Device Management Card
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const DeviceManagementModal(),
                        );
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 140,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.primaryBlue.withValues(alpha: 0.15),
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
                                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.settings_suggest_rounded, color: AppColors.primaryBlue, size: 14),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "DEVICES",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Nodes Management",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Configuration",
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 32),
        // Logs Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.list_alt, color: AppColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  "Device Activity Logs",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            _BouncingFilterButton(onTap: _openFilterModal),
          ],
        ),
        const SizedBox(height: 4),
        
        ..._buildFilteredLogWidgets(),
      ],
    );
  }

  Widget _buildDevicesList() {
    if (widget.deviceData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      children: widget.deviceData.map((device) {
        final isOnline = device['isOnline'] == true;
        final name = device['location'] ?? 'Unknown Location';
        final macAddress = device['mac'] ?? 'Unknown MAC';
        final type = 'Multi-Sensor Node'; 
        final powerStatus = device['power_status']?.toString() ?? 'Unknown';

        IconData powerIcon;
        Color powerColor = AppColors.textGrey;
        if (powerStatus.toLowerCase() == 'high') {
          powerIcon = Icons.battery_full;
          powerColor = AppColors.statusSafe;
        } else if (powerStatus.toLowerCase() == 'adequate') {
          powerIcon = Icons.battery_4_bar;
          powerColor = AppColors.statusWarning;
        } else if (powerStatus.toLowerCase() == 'low') {
          powerIcon = Icons.battery_alert;
          powerColor = AppColors.statusDanger;
        } else {
          powerIcon = Icons.battery_unknown;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOnline 
                      ? AppColors.primaryRose.withValues(alpha: 0.2)
                      : AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.memory, 
                  color: isOnline ? AppColors.primaryRose : AppColors.textGrey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textLight,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "$macAddress • $type",
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline ? AppColors.primaryRose : AppColors.textGrey,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? "Online" : "Offline",
                        style: TextStyle(
                          color: isOnline ? AppColors.primaryRose : AppColors.textGrey,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        powerIcon,
                        color: powerColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        powerStatus,
                        style: TextStyle(
                          color: powerColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _openFilterModal() {
    // Temporary variables for modal's local state before applying
    DateTime? tempDate = selectedFilterDate;
    List<String> tempSensors = List.from(selectedSensorTypes);
    List<String> tempExcludedSensors = List.from(excludedSensorTypes);
    List<String> tempPriorities = List.from(selectedPriorities);

    showDialog(
      context: context,
      barrierColor: Colors.black45, // Translucent underlying barrier
      builder: (context) {
        return TweenAnimationBuilder(
          duration: const Duration(milliseconds: 450), // Slower animation as requested
          tween: Tween<double>(begin: 0.0, end: 1.0),
          curve: Curves.easeOutBack,
          builder: (context, double value, child) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0 * value, sigmaY: 8.0 * value),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setModalState) {
                      return Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.1),
                                  blurRadius: Theme.of(context).brightness == Brightness.dark ? 20 : 30,
                                  offset: Offset(0, Theme.of(context).brightness == Brightness.dark ? 10 : 15),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Filter Logs",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              setModalState(() {
                                                tempDate = null;
                                                tempSensors.clear();
                                                tempExcludedSensors.clear();
                                                tempPriorities.clear();
                                              });
                                            },
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: const Text("Clear All", style: TextStyle(color: AppColors.statusDanger)),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () => Navigator.pop(context),
                                            icon: const Icon(Icons.close, color: AppColors.textGrey),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                      
                      // 1. DATE FILTER
                      Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: AppColors.primaryBlue,
                                    onPrimary: Colors.white,
                                    surface: AppColors.surfaceDark,
                                    onSurface: AppColors.textLight,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setModalState(() {
                              tempDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tempDate != null ? DateFormat('MMMM d, yyyy').format(tempDate!) : "Select Date",
                                style: TextStyle(color: tempDate != null ? AppColors.textLight : AppColors.textGrey),
                              ),
                              const Icon(Icons.calendar_today, color: AppColors.textGrey, size: 20),
                            ],
                          ),
                        ),
                      ),
                      if (tempDate != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setModalState(() => tempDate = null),
                            child: Text("Clear Date", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                          ),
                        )
                      else
                        const SizedBox(height: 24),

                      // 2. LOG TYPE FILTER
                      Text("Log Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['People Counter', 'Flame', 'Smoke', 'Temperature', 'Power', 'Connectivity', 'User Activity', 'Emergency', 'System'].map((sensor) {
                          final isSelected = tempSensors.contains(sensor);
                          return FilterChip(
                            label: Text(sensor),
                            selected: isSelected,
                            showCheckmark: false,
                            onSelected: (bool selected) {
                              setModalState(() {
                                if (selected) {
                                  tempSensors.add(sensor);
                                  tempExcludedSensors.remove(sensor); // Ensure mutually exclusive
                                } else {
                                  tempSensors.remove(sensor);
                                }
                              });
                            },
                            selectedColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? AppColors.primaryBlue : Colors.white24),
                            ),
                            labelStyle: TextStyle(color: isSelected ? AppColors.primaryBlue : Theme.of(context).colorScheme.onSurfaceVariant),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // 2.5 EXCLUDE LOG TYPE FILTER
                      Text("Exclude Log Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['People Counter', 'Flame', 'Smoke', 'Temperature', 'Power', 'Connectivity', 'User Activity', 'Emergency', 'System'].map((sensor) {
                          final isExcluded = tempExcludedSensors.contains(sensor);
                          return FilterChip(
                            label: Text(sensor),
                            selected: isExcluded,
                            showCheckmark: false,
                            onSelected: (bool selected) {
                              setModalState(() {
                                if (selected) {
                                  tempExcludedSensors.add(sensor);
                                  tempSensors.remove(sensor); // Ensure mutually exclusive
                                } else {
                                  tempExcludedSensors.remove(sensor);
                                }
                              });
                            },
                            selectedColor: AppColors.statusDanger.withValues(alpha: 0.3),
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isExcluded ? AppColors.statusDanger : Colors.white24),
                            ),
                            labelStyle: TextStyle(color: isExcluded ? AppColors.statusDanger : Theme.of(context).colorScheme.onSurfaceVariant),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // 3. PRIORITY FILTER
                      Text("Emergency Priority", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: ['High', 'Mid', 'Low'].map((priority) {
                          final isSelected = tempPriorities.contains(priority);
                          Color pColor;
                          if (priority == 'High') {
                            pColor = AppColors.statusDanger;
                          } else if (priority == 'Mid') {
                            pColor = AppColors.statusWarning;
                          } else {
                            pColor = AppColors.statusSafe;
                          }

                          return FilterChip(
                            label: Text(priority),
                            selected: isSelected,
                            showCheckmark: false,
                            onSelected: (bool selected) {
                              setModalState(() {
                                if (selected) {
                                  tempPriorities.add(priority);
                                } else {
                                  tempPriorities.remove(priority);
                                }
                              });
                            },
                            selectedColor: pColor.withValues(alpha: 0.2),
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? pColor : Colors.white24),
                            ),
                            labelStyle: TextStyle(color: isSelected ? pColor : Theme.of(context).colorScheme.onSurfaceVariant),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 32),
                      
                      // Apply Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedFilterDate = tempDate;
                              selectedSensorTypes = List.from(tempSensors);
                              excludedSensorTypes = List.from(tempExcludedSensors);
                              selectedPriorities = List.from(tempPriorities);
                              _currentPage = 1;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            "Apply Filters",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
          },
        );
      },
    );
  }
 
  List<Widget> _buildFilteredLogWidgets() {
    // 1. Filter Logs
    List<DeviceLog> filteredLogs = _firestoreLogs.where((log) {
      bool matchesDate = true;
      if (selectedFilterDate != null) {
        matchesDate = log.dateTime.year == selectedFilterDate!.year &&
                      log.dateTime.month == selectedFilterDate!.month &&
                      log.dateTime.day == selectedFilterDate!.day;
      }
      
      // Map friendly chip labels → raw Firestore type values for matching
      const chipToRawType = {
        'People Counter': 'tof',
        'Flame': 'flame',
        'Smoke': 'gas',
        'Temperature': 'temperature',
        'Power': 'power',
        'Connectivity': 'connectivity',
        'User Activity': 'user',
        'Emergency': 'siren',
        'System': 'system',
      };

      bool matchesSensor = true;
      if (selectedSensorTypes.isNotEmpty) {
        final rawTypes = selectedSensorTypes.map((chip) => chipToRawType[chip] ?? chip).toSet();
        matchesSensor = rawTypes.contains(log.logTypeRaw);
      }

      bool isExcluded = false;
      if (excludedSensorTypes.isNotEmpty) {
        final excludedRaw = excludedSensorTypes.map((chip) => chipToRawType[chip] ?? chip).toSet();
        isExcluded = excludedRaw.contains(log.logTypeRaw);
      }

      bool matchesPriority = true;
      if (selectedPriorities.isNotEmpty) {
        matchesPriority = selectedPriorities.contains(log.priority);
      }

      return matchesDate && matchesSensor && !isExcluded && matchesPriority;
    }).toList();

    if (filteredLogs.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              "No logs match the current filters.",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
            ),
          ),
        ),
      ];
    }

    // PAGINATION LOGIC
    int effectiveLimit = _explicitLogsPerPage ?? 10;
    int totalLogs = filteredLogs.length;
    int totalPages = (totalLogs / effectiveLimit).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    int startIndex = (_currentPage - 1) * effectiveLimit;
    int endIndex = startIndex + effectiveLimit;
    if (endIndex > totalLogs) endIndex = totalLogs;

    List<DeviceLog> paginatedLogs = filteredLogs.sublist(startIndex, endIndex);

    // 2. Group by Date
    Map<String, List<DeviceLog>> groupedLogs = {};
    for (var log in paginatedLogs) {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final logDate = DateTime(log.dateTime.year, log.dateTime.month, log.dateTime.day);
      final difference = todayDate.difference(logDate).inDays;
      
      String relativeTimeStr;

      if (difference == 0) {
        relativeTimeStr = "TODAY";
      } else if (difference == 1) {
        relativeTimeStr = "YESTERDAY";
      } else if (difference < 7) {
        relativeTimeStr = "${difference}D AGO";
      } else if (difference < 30) {
        final weeks = difference ~/ 7;
        relativeTimeStr = "${weeks}W AGO";
      } else if (difference < 365) {
        final months = difference ~/ 30;
        relativeTimeStr = "${months}M AGO";
      } else {
        final years = difference ~/ 365;
        relativeTimeStr = "${years}Y AGO";
      }

      String dateKey = "${DateFormat('MMM d, yyyy').format(log.dateTime)} // $relativeTimeStr";

      if (!groupedLogs.containsKey(dateKey)) {
        groupedLogs[dateKey] = [];
      }
      groupedLogs[dateKey]!.add(log);
    }

    // 3. Build Widgets
    List<Widget> widgets = [];
    groupedLogs.forEach((dateKey, logs) {
      final parts = dateKey.split(" // ");
      final dateStr = parts[0];
      final relativeStr = parts.length > 1 ? parts[1] : "";
      
      widgets.add(_buildDateHeader(dateStr, relativeStr, logs.length));
      for (var log in logs) {
        widgets.add(_buildLogItem(log));
      }
      widgets.add(const SizedBox(height: 16));
    });

    // 4. Pagination Controls
    if (totalLogs > 0) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: _currentPage > 1 ? AppColors.primaryBlue : AppColors.textGrey.withValues(alpha: 0.5),
                    onPressed: _currentPage > 1 ? () {
                      setState(() => _currentPage--);
                    } : null,
                    style: IconButton.styleFrom(
                      backgroundColor: _currentPage > 1 ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      "Page $_currentPage of $totalPages",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: _currentPage < totalPages ? AppColors.primaryBlue : AppColors.textGrey.withValues(alpha: 0.5),
                    onPressed: _currentPage < totalPages ? () {
                      setState(() => _currentPage++);
                    } : null,
                    style: IconButton.styleFrom(
                      backgroundColor: _currentPage < totalPages ? AppColors.primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Logs per page selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Show:",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPageSizeButton(5),
                  _buildPageSizeButton(10),
                  _buildPageSizeButton(20),
                  _buildPageSizeButton(50),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildPageSizeButton(int size) {
    final isSelected = _explicitLogsPerPage == size;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _explicitLogsPerPage = null; // Unselect everything, goes back to 10 default
          } else {
            _explicitLogsPerPage = size;
          }
          _currentPage = 1;
        });
        _scrollToBottom();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.white10,
            width: 1,
          ),
        ),
        child: Text(
          size.toString(),
          style: TextStyle(
            color: isSelected ? AppColors.primaryBlue : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.parentScrollController != null && widget.parentScrollController!.hasClients) {
        widget.parentScrollController!.animateTo(
          widget.parentScrollController!.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildLogItem(DeviceLog log) {
    final isHighlighted = widget.highlightedLogId == log.id;
    final itemKey = isHighlighted ? widget.highlightedItemKey : null;

    return AnimatedContainer(
      key: itemKey,
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isHighlighted 
            ? log.iconColor.withValues(alpha: 0.15) 
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted 
              ? log.iconColor.withValues(alpha: 0.8) 
              : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
          width: isHighlighted ? 2.0 : 1.0,
        ),
        boxShadow: isHighlighted ? [
          BoxShadow(
            color: log.iconColor.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.03),
            blurRadius: Theme.of(context).brightness == Brightness.dark ? 10 : 20,
            offset: Offset(0, Theme.of(context).brightness == Brightness.dark ? 4 : 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showLogDetailsModal(context, log),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left color indicator strip
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: log.iconColor,
                    boxShadow: [
                      BoxShadow(
                        color: log.iconColor.withValues(alpha: isHighlighted ? 0.8 : 0.4),
                        blurRadius: isHighlighted ? 8 : 4,
                        spreadRadius: isHighlighted ? 2 : 1,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 16, bottom: 16, right: 16),
                    child: Row(
                      children: [
                        // Sensor Icon
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: log.iconColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(log.icon, color: log.iconColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        // Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      log.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (log.logEvent != 'evacuation_siren_manual')
                                    _buildSmallStatusBadge(log.currentStatus),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MM/dd/yy HH:mm:ss').format(log.dateTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                log.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Unread dot + chevron
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (log.isUnread) Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.statusSafe,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.statusSafe.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          ],
                        ),
                      ],
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

  Widget _buildSmallStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    if (status == 'Active') {
      bgColor = AppColors.statusDanger.withValues(alpha: 0.15);
      textColor = AppColors.statusDanger;
    } else if (status == 'Resolved' || status == 'Acknowledged' || status == 'Deactivated') {
      bgColor = AppColors.statusSafe.withValues(alpha: 0.15);
      textColor = AppColors.statusSafe;
    } else if (status == 'Unresolved') {
      bgColor = AppColors.statusWarning.withValues(alpha: 0.15);
      textColor = AppColors.statusWarning;
    } else {
      bgColor = AppColors.statusWarning.withValues(alpha: 0.15);
      textColor = AppColors.statusWarning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final Color chipColor = role.toLowerCase() == 'admin'
        ? AppColors.statusDanger
        : const Color(0xFFD4A017); // Gold for Facilitator
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: chipColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }



  void _showLogDetailsModal(BuildContext context, DeviceLog log) {
    final priorityColor = log.priority == 'High'
        ? AppColors.statusDanger
        : log.priority == 'Mid'
            ? AppColors.statusWarning
            : AppColors.statusSafe;

    final userProvider = context.read<UserProvider>();
    final currentUserEmail = userProvider.email;

    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            return TweenAnimationBuilder(
              duration: const Duration(milliseconds: 350),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (_, double value, __) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8.0 * value, sigmaY: 8.0 * value),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(dialogContext).colorScheme.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Theme.of(dialogContext).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: Theme.of(dialogContext).brightness == Brightness.dark ? 0.6 : 0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Header ──
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: log.iconColor.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(log.icon, color: log.iconColor, size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        log.title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(dialogContext).colorScheme.onSurface,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.close,
                                          color: Theme.of(dialogContext).colorScheme.onSurfaceVariant),
                                      onPressed: () => Navigator.pop(dialogContext),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // ── Message banner ──
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: log.iconColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: log.iconColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline, color: log.iconColor, size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          log.message,
                                          style: TextStyle(
                                            color: Theme.of(dialogContext).colorScheme.onSurface,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ── Section 1: Common fields ──
                                _detailRow(dialogContext, 'Timestamp',
                                    DateFormat('MMM dd, yyyy – HH:mm:ss').format(log.dateTime)),

                                // Priority — shown for all types (always LOW for user/tof)
                                _detailRow(dialogContext, 'Priority', log.priority.toUpperCase(),
                                    valueColor: priorityColor),

                                // Status — only for types where it matters
                                if (log.showStatus) ...[
                                  if (log.isResolvable) ...[
                                    // Connectivity offline — UNRESOLVED / resolved row
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Status',
                                              style: TextStyle(
                                                  color: Theme.of(dialogContext)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 13)),
                                          log.isResolved
                                              ? _buildSmallStatusBadge('Resolved')
                                              : _buildSmallStatusBadge('Unresolved'),
                                        ],
                                      ),
                                    ),
                                    // Mark Resolved button (only if not yet resolved)
                                    if (!log.isResolved) ...[
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            await ActivityLogService.markConnectivityResolved(
                                              docId: log.id,
                                              resolvedByEmail: currentUserEmail,
                                            );
                                            if (dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }
                                          },
                                          icon: Icon(Icons.check_circle_outline_rounded,
                                              size: 16, color: AppColors.statusSafe),
                                          label: const Text('MARK RESOLVED',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.8)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.statusSafe,
                                            side: BorderSide(
                                                color: AppColors.statusSafe.withValues(alpha: 0.5)),
                                            backgroundColor:
                                                AppColors.statusSafe.withValues(alpha: 0.05),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 10),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ] else if (log.resolvedBy != null) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Resolved by',
                                                style: TextStyle(
                                                    color: Theme.of(dialogContext)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 13)),
                                            Text(log.resolvedBy!,
                                                style: TextStyle(
                                                    color: AppColors.statusSafe,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ] else ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Status',
                                            style: TextStyle(
                                                color: Theme.of(dialogContext)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 13)),
                                        _buildSmallStatusBadge(log.currentStatus),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],

                                const Divider(height: 28),

                                // ── Section 2: Type-specific fields ──

                                // Location (hidden for user logs)
                                if (log.showLocation)
                                  _detailRow(dialogContext, 'Location', log.specificZone),

                                // Log Type label (friendly sensor name)
                                _detailRow(dialogContext, 'Log Type', log.sensorType),

                                // User log extras: Role chip + Platform + Email
                                if (log.logTypeRaw == 'user') ...[
                                  if (log.role != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Role',
                                              style: TextStyle(
                                                  color: Theme.of(dialogContext)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 13)),
                                          _buildRoleChip(log.role!),
                                        ],
                                      ),
                                    ),
                                  if (log.userEmail != null && log.userEmail!.isNotEmpty)
                                    _detailRow(dialogContext, 'Email', log.userEmail!),
                                  if (log.platform != null)
                                    _detailRow(dialogContext, 'Platform', log.platform!),
                                ],

                                // Connectivity extra: resolved by
                                if (log.logTypeRaw == 'connectivity' &&
                                    log.logEvent == 'device_online' &&
                                    log.resolvedBy != null)
                                  _detailRow(dialogContext, 'Recovery Note',
                                      'Previously resolved by ${log.resolvedBy}'),

                                // Hazard extras
                                if (log.sirenActivated != null)
                                  _detailRow(
                                    dialogContext,
                                    'Siren State',
                                    log.sirenActivated! ? 'Activated' : 'Standby',
                                    valueColor:
                                        log.sirenActivated! ? AppColors.statusDanger : null,
                                  ),

                                // Manual evacuation siren — who triggered it
                                if (log.triggeredBy != null && log.triggeredBy!.isNotEmpty) ...[
                                  _detailRow(dialogContext, 'Triggered By', log.triggeredBy!),
                                  if (log.triggeredByRole != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Role',
                                              style: TextStyle(
                                                  color: Theme.of(dialogContext)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 13)),
                                          _buildRoleChip(log.triggeredByRole!),
                                        ],
                                      ),
                                    ),
                                  if (log.triggeredByEmail != null &&
                                      log.triggeredByEmail!.isNotEmpty)
                                    _detailRow(dialogContext, 'Email', log.triggeredByEmail!),
                                ],

                                // Power extras
                                if (log.powerStatus != null)
                                  _detailRow(
                                    dialogContext,
                                    'Power Level',
                                    log.powerStatus!,
                                    valueColor: log.powerStatus == 'Low'
                                        ? AppColors.statusDanger
                                        : log.powerStatus == 'Adequate'
                                            ? AppColors.statusWarning
                                            : AppColors.statusSafe,
                                  ),

                                const SizedBox(height: 8),
                              ],
                            ),
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
      },
    );
  }


  Widget _detailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                fontWeight: valueColor != null ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetailsModal(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black54,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: isDark ? 0.92 : 0.97),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Grab Handle ─────────────────────────────
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // ── Header ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          title.toLowerCase().contains('power') ? Icons.bolt_rounded : Icons.router_rounded,
                          color: AppColors.primaryBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.replaceAll('\n', ' '),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "4 sensors tracked",
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
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        const SizedBox(height: 24),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("LOCATION", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                                  Text(title.toLowerCase().contains('power') ? "POWER" : "STATUS", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                                ],
                              ),
                              Divider(height: 32, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),

                              if (title.toLowerCase().contains('power')) ...[
                                StreamBuilder<DatabaseEvent>(
                                  stream: FirebaseDatabase.instance.ref().child('prototype_units').onValue,
                                  builder: (context, protoSnap) {
                                    return StreamBuilder<DatabaseEvent>(
                                      stream: FirebaseDatabase.instance.ref().child('sensor_data').onValue,
                                      builder: (context, sensorSnap) {
                                        if (!protoSnap.hasData || !sensorSnap.hasData) {
                                          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)));
                                        }
                                        final protoMap = protoSnap.data!.snapshot.value as Map? ?? {};
                                        final sensorMap = sensorSnap.data!.snapshot.value as Map? ?? {};

                                        // Build sorted device list
                                        final devices = <Map<String, dynamic>>[];
                                        protoMap.forEach((mac, val) {
                                          if (val is Map) {
                                            final name = val['name']?.toString() ?? mac.toString();
                                            int priority = 999;
                                            if (val.containsKey('priority')) priority = (val['priority'] is int) ? val['priority'] : int.tryParse(val['priority'].toString()) ?? 999;
                                            final sensorVal = sensorMap[mac] as Map?;
                                            String powerStatus = 'Unknown';
                                            if (sensorVal != null) {
                                               final lastUpdated = sensorVal['last_updated'];
                                               bool isLive = false;
                                               if (lastUpdated != null) {
                                                  final ts = (lastUpdated is int) ? lastUpdated : (lastUpdated as num).toInt();
                                                  final estimatedServerTime = DateTime.now().millisecondsSinceEpoch + widget.serverTimeOffset;
                                                  isLive = (estimatedServerTime - ts).abs() < 45000; // 45s timeout (matches dashboard)
                                               }
                                               if (isLive) {
                                                  powerStatus = sensorVal['power_status']?.toString() ?? 'Unknown';
                                               }
                                            }
                                            devices.add({'name': name, 'power_status': powerStatus, 'priority': priority});
                                          }
                                        });
                                        devices.sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));

                                        if (devices.isEmpty) {
                                          return Center(child: Text("No devices configured", style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5))));
                                        }

                                        return Column(
                                          children: [
                                            for (int i = 0; i < devices.length; i++) ...[
                                              if (i > 0) const SizedBox(height: 10),
                                              _buildDevicePowerRow(devices[i]['name'], devices[i]['power_status']),
                                            ],
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ] else ...[
                                _buildDeviceStatusRow("Main Entrance", true),
                                const SizedBox(height: 10),
                                _buildDeviceStatusRow("Central Stairs", true),
                                const SizedBox(height: 10),
                                _buildDeviceStatusRow("Parking Entrance", true),
                                const SizedBox(height: 10),
                                _buildDeviceStatusRow("Parking Side", false),
                              ],
                              
                              const SizedBox(height: 32),
                              Center(
                                child: Text(
                                  "Live · Auto-refreshing",
                                  style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 48), // Extra padding at bottom for better feel
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceStatusRow(String location, bool isConnected) {
    final statusColor = isConnected ? AppColors.statusSafe : AppColors.statusDanger;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            location,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedPulsingDot(color: statusColor, size: 6.0),
                const SizedBox(width: 8),
                Text(
                  isConnected ? "ONLINE" : "OFFLINE",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildDevicePowerRow(String location, String powerStatus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor;
    IconData statusIcon;
    bool isLow = false;

    switch (powerStatus.toLowerCase()) {
      case 'high':
        statusColor = AppColors.statusSafe;
        statusIcon = Icons.bolt_rounded;
        break;
      case 'adequate':
        statusColor = AppColors.statusWarning;
        statusIcon = Icons.bolt_rounded;
        break;
      case 'low':
        statusColor = AppColors.statusDanger;
        statusIcon = Icons.warning_amber_rounded;
        isLow = true;
        break;
      default:
        statusColor = colorScheme.onSurfaceVariant;
        statusIcon = Icons.help_outline_rounded;
        break;
    }

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 13, color: statusColor),
          const SizedBox(width: 4),
          Text(
            powerStatus.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.5,
              color: statusColor,
            ),
          ),
        ],
      ),
    );

    // Wrap in blinking animation for LOW
    if (isLow) {
      badge = _BlinkingWidget(child: badge);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              location,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          badge,
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date, String relative, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 12),
      child: Row(
        children: [
          // ── Date & Relative Label Capsule ──────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.3 : 0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (relative.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          width: 1.5,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      Text(
                        relative,
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 10),
          
          // ── Count Badge ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1.2,
              ),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          
          // Spacer line to fill the rest of the row
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 12),
              child: Divider(thickness: 1, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowingStatusCard extends StatefulWidget {
  final String title;
  final int count;
  final Color color;

  const _GlowingStatusCard({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  State<_GlowingStatusCard> createState() => _GlowingStatusCardState();
}

class _GlowingStatusCardState extends State<_GlowingStatusCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // Fallback underlying color
        gradient: LinearGradient(
          colors: [
            widget.color.withValues(alpha: 0.25),
            widget.color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.8),
                      blurRadius: _glowAnimation.value,
                      spreadRadius: _glowAnimation.value / 3,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.color.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.count.toString(),
            style: TextStyle(
              color: widget.color,
              fontWeight: FontWeight.w900,
              fontSize: 32,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _BouncingFilterButton extends StatefulWidget {
  final VoidCallback onTap;

  const _BouncingFilterButton({required this.onTap});

  @override
  State<_BouncingFilterButton> createState() => _BouncingFilterButtonState();
}

class _BouncingFilterButtonState extends State<_BouncingFilterButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 100),
       reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
         setState(() => _isPressed = false);
         _controller.reverse();
         widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isPressed ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt, color: Theme.of(context).colorScheme.onSurface, size: 16),
              const SizedBox(width: 6),
              Text(
                "Filter",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBouncingDeviceCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _AnimatedBouncingDeviceCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_AnimatedBouncingDeviceCard> createState() => _AnimatedBouncingDeviceCardState();
}

class _AnimatedBouncingDeviceCardState extends State<_AnimatedBouncingDeviceCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 100),
       reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
         setState(() => _isPressed = false);
         _controller.reverse();
         widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 135,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: _isPressed 
                ? (Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03))
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              if (!_isPressed)
                BoxShadow(
                  color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.02),
                  blurRadius: Theme.of(context).brightness == Brightness.dark ? 10 : 15,
                  offset: Offset(0, Theme.of(context).brightness == Brightness.dark ? 4 : 8),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 24),
              const Spacer(),
              Text(
                widget.title.replaceAll('\n', ' '), 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                "Tap to manage",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedPulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _AnimatedPulsingDot({required this.color, this.size = 8.0});

  @override
  State<_AnimatedPulsingDot> createState() => _AnimatedPulsingDotState();
}

class _AnimatedPulsingDotState extends State<_AnimatedPulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: widget.size * 0.5, end: widget.size * 1.5).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.8),
                blurRadius: _glowAnimation.value,
                spreadRadius: _glowAnimation.value / 3,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BlinkingLightningIcon extends StatefulWidget {
  const _BlinkingLightningIcon();

  @override
  State<_BlinkingLightningIcon> createState() => _BlinkingLightningIconState();
}

class _BlinkingLightningIconState extends State<_BlinkingLightningIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: const Icon(
            Icons.bolt,
            color: Colors.red,
            size: 16,
          ),
        );
      },
    );
  }
}

class _BlinkingWidget extends StatefulWidget {
  final Widget child;
  const _BlinkingWidget({required this.child});

  @override
  State<_BlinkingWidget> createState() => _BlinkingWidgetState();
}

class _BlinkingWidgetState extends State<_BlinkingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + (_controller.value * 0.7),
          child: widget.child,
        );
      },
    );
  }
}
