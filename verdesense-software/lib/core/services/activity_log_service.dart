import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized service for writing structured activity logs to Cloud Firestore.
///
/// All logs are written to the `activity_logs` collection with a shared schema:
/// - `type`: category (user, tof, flame, gas, temperature, siren, power, connectivity)
/// - `priority`: CRITICAL | WARNING | INFO
/// - Common contextual fields (deviceMAC, location, timestamp, message)
class ActivityLogService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'activity_logs';

  // ---------------------------------------------------------------------------
  // Private helper
  // ---------------------------------------------------------------------------

  static Future<void> _write({
    required String type,
    required String priority,
    required String message,
    String? deviceMAC,
    String? location,
    Map<String, dynamic> extra = const {},
    String? docId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      final data = {
        'type': type,
        'priority': priority,
        'message': message,
        'deviceMAC': deviceMAC,
        'location': location,
        'userId': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        ...extra,
      };

      if (docId != null) {
        await _firestore
            .collection(_collection)
            .doc(docId)
            .set(data, SetOptions(merge: true));
      } else {
        await _firestore.collection(_collection).add(data);
      }
    } catch (e) {
      // Silently fail — logging should never crash the app
      // ignore: avoid_print
      print('[ActivityLogService] Write failed: $e');
    }
  }

  // ===========================================================================
  // 1. USER ACTIVITY
  // ===========================================================================

  static Future<void> logUserLogin({
    required String email,
    required String username,
    required String role,
    required String platform,
  }) =>
      _write(
        type: 'user',
        priority: 'INFO',
        message: '$username logged in on $platform',
        extra: {
          'event': 'login',
          'email': email,
          'username': username,
          'role': role,
          'platform': platform
        },
      );

  static Future<void> logUserLogout({required String email}) => _write(
        type: 'user',
        priority: 'INFO',
        message: '$email logged out',
        extra: {'event': 'logout', 'email': email},
      );

  static Future<void> logDeviceAdded({
    required String deviceMAC,
    required String deviceName,
  }) =>
      _write(
        type: 'user',
        priority: 'INFO',
        message: 'Device added: $deviceName ($deviceMAC)',
        deviceMAC: deviceMAC,
        extra: {'event': 'device_added', 'deviceName': deviceName},
      );

  static Future<void> logDeviceRemoved({
    required String deviceMAC,
    required String deviceName,
  }) =>
      _write(
        type: 'user',
        priority: 'WARNING',
        message: 'Device removed: $deviceName ($deviceMAC)',
        deviceMAC: deviceMAC,
        extra: {'event': 'device_removed', 'deviceName': deviceName},
      );

  static Future<void> logDeviceSettingsChanged({
    required String deviceMAC,
    required String field,
    required dynamic oldValue,
    required dynamic newValue,
  }) =>
      _write(
        type: 'user',
        priority: 'INFO',
        message: 'Settings changed: $field ($oldValue → $newValue)',
        deviceMAC: deviceMAC,
        extra: {
          'event': 'settings_changed',
          'field': field,
          'oldValue': '$oldValue',
          'newValue': '$newValue'
        },
      );

  // ===========================================================================
  // 2. TIME-OF-FLIGHT (ToF)
  // ===========================================================================

  static Future<void> logHourlySnapshot({
    required String deviceMAC,
    required String location,
    required int entriesThisHour,
    required int exitsThisHour,
    required int resetHour,
  }) =>
      _write(
        type: 'tof',
        priority: 'INFO',
        message:
            '$location hourly snapshot: $entriesThisHour entries and $exitsThisHour exits.',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'hourly_snapshot',
          'entriesThisHour': entriesThisHour,
          'exitsThisHour': exitsThisHour,
          'resetHour': resetHour,
        },
      );

  // ===========================================================================
  // 3. FLAME SENSOR
  // ===========================================================================

  static Future<void> logFlameDetected({
    required String deviceMAC,
    required String location,
    required String sensorType, // "backup_analog" or "main_digital"
    int? rawValue,
  }) =>
      _write(
        type: 'flame',
        priority: 'CRITICAL',
        message: '🔥 Flame detected at $location ($sensorType)',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'flame_detected',
          'sensorType': sensorType,
          if (rawValue != null) 'rawValue': rawValue
        },
      );

  static Future<void> logFlameCleared({
    required String deviceMAC,
    required String location,
    int? durationSeconds,
  }) =>
      _write(
        type: 'flame',
        priority: 'INFO',
        message: 'Flame cleared at $location',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'flame_cleared',
          if (durationSeconds != null) 'durationSeconds': durationSeconds
        },
      );

  // ===========================================================================
  // 4. GAS / SMOKE
  // ===========================================================================

  static Future<void> logGasDetected({
    required String deviceMAC,
    required String location,
    required int rawValue,
    int? percentage,
  }) =>
      _write(
        type: 'gas',
        priority: 'CRITICAL',
        message: '💨 Gas/Smoke detected at $location (raw: $rawValue)',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'gas_detected',
          'rawValue': rawValue,
          if (percentage != null) 'percentage': percentage
        },
      );

  static Future<void> logGasCleared({
    required String deviceMAC,
    required String location,
    int? peakValue,
    int? durationSeconds,
  }) =>
      _write(
        type: 'gas',
        priority: 'INFO',
        message: 'Gas/Smoke cleared at $location',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'gas_cleared',
          if (peakValue != null) 'peakValue': peakValue,
          if (durationSeconds != null) 'durationSeconds': durationSeconds,
        },
      );

  // ===========================================================================
  // 5. TEMPERATURE
  // ===========================================================================

  static Future<void> logHighTemperature({
    required String deviceMAC,
    required String location,
    required double currentTemp,
    required double threshold,
  }) =>
      _write(
        type: 'temperature',
        priority: currentTemp >= 50 ? 'CRITICAL' : 'WARNING',
        message:
            '🌡️ High temp at $location: ${currentTemp.toStringAsFixed(1)}°C (threshold: ${threshold.toStringAsFixed(1)}°C)',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'high_temperature',
          'currentTemp': currentTemp,
          'threshold': threshold
        },
      );

  static Future<void> logTemperatureNormalized({
    required String deviceMAC,
    required String location,
    double? peakTemp,
  }) =>
      _write(
        type: 'temperature',
        priority: 'INFO',
        message: 'Temperature normalized at $location',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'temperature_normalized',
          if (peakTemp != null) 'peakTemp': peakTemp
        },
      );

  static Future<void> logSensorFault({
    required String deviceMAC,
    required String location,
  }) =>
      _write(
        type: 'temperature',
        priority: 'WARNING',
        message: '⚠️ Temperature sensor fault at $location (reading: -127°C)',
        deviceMAC: deviceMAC,
        location: location,
        extra: {'event': 'sensor_fault', 'rawValue': -127},
      );

  // ===========================================================================
  // 6. SIREN / EMERGENCY
  // ===========================================================================

  static Future<void> logSirenActivated({
    required String deviceMAC,
    required String location,
    required int flameValue,
    required int gasValue,
  }) =>
      _write(
        type: 'siren',
        priority: 'CRITICAL',
        message:
            '🚨 Siren activated at $location (flame: $flameValue, gas: $gasValue)',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'siren_activated',
          'triggerSource': 'flame+gas',
          'flameValue': flameValue,
          'gasValue': gasValue
        },
      );

  /// Logs a manual EVACUATION SIREN trigger from the app (app-user-initiated).
  /// Returns the Firestore document ID so the caller can later update the status.
  static Future<String?> logEvacuationSirenTriggered({
    required String triggeredByName,
    required String triggeredByRole,
    required String triggeredByEmail,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final ref = await _firestore.collection(_collection).add({
        'type': 'siren',
        'priority': 'CRITICAL',
        'message': '🚨 EVACUATION SIREN TRIGGERED by $triggeredByName',
        'location': 'All Sites',
        'userId': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'event': 'evacuation_siren_manual',
        'triggerSource': 'manual_app',
        'triggeredByName': triggeredByName,
        'triggeredByRole': triggeredByRole,
        'triggeredByEmail': triggeredByEmail,
        'sirenStatus':
            'Active', // Will be updated to 'Deactivated' on terminate
      });
      return ref.id;
    } catch (e) {
      // ignore: avoid_print
      print('[ActivityLogService] logEvacuationSirenTriggered failed: $e');
      return null;
    }
  }

  /// Updates the sirenStatus of an existing evacuation siren log to 'Deactivated'.
  static Future<void> markEvacuationSirenDeactivated({String? docId}) async {
    try {
      if (docId != null) {
        // Fast path: update by known doc ID
        await _firestore.collection(_collection).doc(docId).update({
          'sirenStatus': 'Deactivated',
        });
      } else {
        // Fallback: query the most recent active evacuation siren log and update it
        final query = await _firestore
            .collection(_collection)
            .where('event', isEqualTo: 'evacuation_siren_manual')
            .where('sirenStatus', isEqualTo: 'Active')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        for (final doc in query.docs) {
          await doc.reference.update({'sirenStatus': 'Deactivated'});
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[ActivityLogService] markEvacuationSirenDeactivated failed: $e');
    }
  }

  static Future<void> logSirenDeactivated({
    required String deviceMAC,
    required String location,
    int? activeDurationSeconds,
  }) =>
      _write(
        type: 'siren',
        priority: 'INFO',
        message: 'Siren deactivated at $location',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'siren_deactivated',
          if (activeDurationSeconds != null)
            'activeDurationSeconds': activeDurationSeconds
        },
      );

  static Future<void> logManualSirenAlert({
    required String deviceMAC,
    required String location,
  }) =>
      _write(
        type: 'siren',
        priority: 'CRITICAL',
        message: '🚨 Manual siren alert triggered at $location',
        deviceMAC: deviceMAC,
        location: location,
        extra: {'event': 'manual_siren_alert'},
      );

  static Future<void> logManualSirenClear({
    required String deviceMAC,
    required String location,
  }) =>
      _write(
        type: 'siren',
        priority: 'INFO',
        message: 'Manual siren cleared at $location',
        deviceMAC: deviceMAC,
        location: location,
        extra: {'event': 'manual_siren_clear'},
      );

  static Future<void> logDeviceRestart({
    required List<String> devicesAffected,
  }) =>
      _write(
        type: 'siren',
        priority: 'WARNING',
        message:
            'ESP32 device restart triggered (${devicesAffected.length} devices)',
        extra: {
          'event': 'device_restart',
          'devicesAffected': devicesAffected,
          'reason': 'manual_restart'
        },
      );

  // ===========================================================================
  // 7. POWER / BATTERY
  // ===========================================================================

  static Future<void> logPowerLevelChanged({
    required String deviceMAC,
    required String location,
    required String previousLevel,
    required String newLevel,
  }) =>
      _write(
        type: 'power',
        priority: newLevel == 'Low' ? 'WARNING' : 'INFO',
        message: 'Power changed at $location: $previousLevel → $newLevel',
        deviceMAC: deviceMAC,
        location: location,
        extra: {
          'event': 'power_changed',
          'previousLevel': previousLevel,
          'newLevel': newLevel
        },
      );

  // ===========================================================================
  // 8. DEVICE CONNECTIVITY (state-change only)
  // ===========================================================================

  static Future<void> logDeviceCameOnline({
    required String deviceMAC,
    required String location,
    required dynamic lastUpdated, // Used for deterministic ID
    int? previousOfflineSeconds,
  }) {
    final docId = 'online_${deviceMAC}_$lastUpdated';
    return _write(
      type: 'connectivity',
      priority: 'INFO',
      message: '$location came online',
      deviceMAC: deviceMAC,
      location: location,
      docId: docId,
      extra: {
        'event': 'device_online',
        if (previousOfflineSeconds != null)
          'previousOfflineSeconds': previousOfflineSeconds
      },
    );
  }

  static Future<void> logDeviceWentOffline({
    required String deviceMAC,
    required String location,
    required dynamic lastUpdated, // Used for deterministic ID
  }) {
    final docId = 'offline_${deviceMAC}_$lastUpdated';
    return _write(
      type: 'connectivity',
      priority: 'WARNING',
      message: '$location went offline',
      deviceMAC: deviceMAC,
      location: location,
      docId: docId,
      extra: {
        'event': 'device_offline',
        'resolved': false,
        'resolvedBy': null,
      },
    );
  }

  /// Marks a connectivity-offline log as resolved in Firestore.
  /// This update is shared — all users see the resolution in real time.
  static Future<void> markConnectivityResolved({
    required String docId,
    required String resolvedByEmail,
  }) async {
    try {
      await _firestore.collection(_collection).doc(docId).update({
        'resolved': true,
        'resolvedBy': resolvedByEmail,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('[ActivityLogService] markConnectivityResolved failed: $e');
    }
  }

  // ===========================================================================
  // QUERY HELPERS (for the Activity Logs UI)
  // ===========================================================================

  /// Returns a query for all logs, ordered by newest first.
  static Query<Map<String, dynamic>> allLogs({int limit = 50}) => _firestore
      .collection(_collection)
      .orderBy('timestamp', descending: true)
      .limit(limit);

  /// Returns a query filtered by log type.
  static Query<Map<String, dynamic>> logsByType(String type,
          {int limit = 50}) =>
      _firestore
          .collection(_collection)
          .where('type', isEqualTo: type)
          .orderBy('timestamp', descending: true)
          .limit(limit);

  /// Returns a query filtered by priority.
  static Query<Map<String, dynamic>> logsByPriority(String priority,
          {int limit = 50}) =>
      _firestore
          .collection(_collection)
          .where('priority', isEqualTo: priority)
          .orderBy('timestamp', descending: true)
          .limit(limit);

  /// Returns a query filtered by device MAC.
  static Query<Map<String, dynamic>> logsByDevice(String deviceMAC,
          {int limit = 50}) =>
      _firestore
          .collection(_collection)
          .where('deviceMAC', isEqualTo: deviceMAC)
          .orderBy('timestamp', descending: true)
          .limit(limit);
}
