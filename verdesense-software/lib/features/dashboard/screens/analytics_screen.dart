import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_title.dart';
import '../../../../core/providers/settings_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  final int activeIndex;
  const AnalyticsScreen({super.key, this.activeIndex = 1});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _sensorDataSubscription;
  StreamSubscription? _offsetSubscription;
  Timer? _heartbeatTimer;
  
  List<Map<String, dynamic>> _devices = [];
  final Map<String, dynamic> _sensorDataCache = {};
  int _serverTimeOffset = 0;

  @override
  void initState() {
    super.initState();
    // WINDOWS SAFETY: Only start streams if we are on this tab, but since Analytics is activeIndex 1, we can start them.
    _offsetSubscription = FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (mounted) {
        setState(() {
          if (event.snapshot.value is int) {
            _serverTimeOffset = event.snapshot.value as int;
          } else if (event.snapshot.value is num) {
            _serverTimeOffset = (event.snapshot.value as num).toInt();
          }
        });
      }
    });
    _listenToSensorData();
    _listenToDevices();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _sensorDataSubscription?.cancel();
    _offsetSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  void _listenToDevices() {
    _devicesSubscription = _dbRef.child('prototype_units').onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final Map<dynamic, dynamic> devicesMap = event.snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, dynamic>> loadedDevices = [];
        
        devicesMap.forEach((key, value) {
          if (value is Map) {
            final device = <String, dynamic>{};
            value.forEach((k, v) => device[k.toString()] = v);
            device['macAddress'] = key.toString();
            
            if (!device.containsKey('sensors') && device.containsKey('config') && device['config'] is Map) {
               final configMap = device['config'] as Map;
               final sensorsStrMap = <String, dynamic>{};
               configMap.forEach((k, v) => sensorsStrMap[k.toString()] = v);
               device['sensors'] = sensorsStrMap;
            } else if (!device.containsKey('sensors')) {
               device['sensors'] = <String, dynamic>{
                  "temp_threshold": 35.0,
                  "smoke_threshold": 300.0,
                  "flame_threshold": 200.0,
               };
            }

            final mac = device['macAddress'];
            final sensorInfo = _sensorDataCache[mac];
            if (sensorInfo != null && sensorInfo is Map) {
              device['sensor_data'] = sensorInfo;
            } else {
              device['sensor_data'] = null;
            }

            loadedDevices.add(device);
          }
        });

        loadedDevices.sort((a, b) {
          final pA = a['priority'] ?? 999;
          final pB = b['priority'] ?? 999;
          return pA.compareTo(pB);
        });

        if (mounted) {
          setState(() {
            _devices = loadedDevices;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _devices = [];
          });
        }
      }
    });
  }

  void _listenToSensorData() {
    _sensorDataSubscription = _dbRef.child('sensor_data').onValue.listen((event) {
      if (event.snapshot.value is Map) {
        final map = event.snapshot.value as Map;
        _sensorDataCache.clear();
        map.forEach((key, val) {
          _sensorDataCache[key.toString()] = val;
        });
        
        if (_devices.isNotEmpty && mounted) {
          setState(() {
            for (final device in _devices) {
              final mac = device['macAddress'];
              final sensorInfo = _sensorDataCache[mac];
              if (sensorInfo != null && sensorInfo is Map) {
                device['sensor_data'] = sensorInfo;
              }
            }
          });
        }
      }
    });
  }

  bool _isHardwareLive(Map<String, dynamic> device) {
    final ds = device['sensor_data']?['device_status'];
    final explicitDeviceFalse = ds == false || ds == "false";

    final lastSeen = device['sensor_data']?['last_updated'];
    if (explicitDeviceFalse || lastSeen == null) return false;
    
    final ts = DateTime.fromMillisecondsSinceEpoch(
      (lastSeen is int) ? lastSeen : (lastSeen as num).toInt(),
    );
    final estimatedServerTime = DateTime.now().add(Duration(milliseconds: _serverTimeOffset));
    return estimatedServerTime.difference(ts).inSeconds.abs() < 360; // 360s timeout (heartbeat is 300s)
  }

  String _lastSeenText(Map<String, dynamic> device) {
    final lastSeen = device['sensor_data']?['last_updated'];
    if (lastSeen == null || lastSeen == 0 || (lastSeen is num && lastSeen < 1000000)) return 'Never connected';
    final ts = DateTime.fromMillisecondsSinceEpoch((lastSeen is int) ? lastSeen : (lastSeen as num).toInt());
    final estimatedServerTime = DateTime.now().add(Duration(milliseconds: _serverTimeOffset));
    final diff = estimatedServerTime.difference(ts).abs();
    if (diff.inSeconds < 5) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          key: ValueKey('Page_${widget.activeIndex}'),
          title: "Analytics"
        ),
        const SizedBox(height: 24),
        
        // --- SECTION 1: Emergency Sensor Trends ---
        _buildSectionTitle(context, "EMERGENCY SENSOR TRENDS"),
        const SizedBox(height: 24),
        
        // --- 1.1 TEMPERATURE READINGS ---
        _buildSubHeader(context, "Temperature Readings", Icons.thermostat_rounded),
        _buildHorizontalSensorRow(
          context,
          children: _devices.map<Widget>((device) {
            final isLive = _isHardwareLive(device);
            final statusTxt = isLive ? "Online" : "Seen ${_lastSeenText(device)}";
            final sensorData = device['sensor_data'] as Map<dynamic, dynamic>? ?? {};
            
            final double currentTemp = (sensorData['temperature'] ?? 0.0).toDouble();

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildChartCard(
                context: context,
                title: device['name'] ?? 'Unknown Node',
                subtitle: statusTxt,
                icon: Icons.device_thermostat,
                color: AppColors.primaryBlue,
                isLive: isLive,
                child: _buildTemperatureChart(currentTemp, isLive),
              ),
            );
          }).toList()..add(const SizedBox(width: 4)),
        ),
        
        const SizedBox(height: 32),

        // --- 1.2 SMOKE READINGS ---
        _buildSubHeader(context, "Smoke Readings", Icons.smoking_rooms_rounded),
        _buildHorizontalSensorRow(
          context,
          children: _devices.map<Widget>((device) {
            final isLive = _isHardwareLive(device);
            final statusTxt = isLive ? "Online" : "Seen ${_lastSeenText(device)}";
            final sensors = device['sensors'] as Map<String, dynamic>? ?? {};
            final sensorData = device['sensor_data'] as Map<dynamic, dynamic>? ?? {};
            
            final double currentGas = isLive ? (sensorData['gas'] ?? 0.0).toDouble() : 0.0;
            final double threshold = (sensorData['smoke_threshold'] ?? sensors['smoke_threshold'] ?? settings.smokeThreshold).toDouble();

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildChartCard(
                context: context,
                title: device['name'] ?? 'Unknown Node',
                subtitle: statusTxt,
                icon: Icons.cloud_outlined,
                color: AppColors.primaryBlue,
                isLive: isLive,
                child: _buildSmokeGauge(context, currentGas, threshold),
              ),
            );
          }).toList()..add(const SizedBox(width: 4)),
        ),

        const SizedBox(height: 32),

        // --- 1.3 FLAME READINGS ---
        _buildSubHeader(context, "Flame Readings", Icons.local_fire_department_rounded),
        _buildHorizontalSensorRow(
          context,
          height: 400,
          children: _devices.map<Widget>((device) {
            final isLive = _isHardwareLive(device);
            final statusTxt = isLive ? "Online" : "Seen ${_lastSeenText(device)}";
            final sensors = device['sensors'] as Map<String, dynamic>? ?? {};
            final sensorData = device['sensor_data'] as Map<dynamic, dynamic>? ?? {};
            
            // Firmware: false means flame is detected.
            final bool mainFlameDetected = isLive ? !(sensorData['main_flame'] as bool? ?? true) : false;
            final double backupPpm = isLive ? (sensorData['backup_flame'] ?? 4095).toDouble() : 4095.0;
            final double backupThreshold = (sensorData['flame_threshold'] ?? sensors['flame_threshold'] ?? settings.flameThreshold).toDouble();

            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildFlameSensorCard(
                context: context,
                title: device['name'] ?? 'Unknown Node',
                subtitle: statusTxt,
                mainFlameDetected: mainFlameDetected,
                backupPpm: backupPpm,
                backupThreshold: backupThreshold,
                isLive: isLive,
              ),
            );
          }).toList()..add(const SizedBox(width: 4)),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildChartCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isLive,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(isLive),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
  
  
  Widget _buildSubHeader(BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSensorRow(BuildContext context, {required List<Widget> children, double height = 320}) {
    return SizedBox(
      height: height,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
          },
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: children,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.0),
                  colorScheme.primary.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: colorScheme.primary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.3),
                  colorScheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isLive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isLive ? AppColors.statusSafe : AppColors.statusDanger).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isLive ? AppColors.statusSafe : AppColors.statusDanger).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isLive ? AppColors.statusSafe : AppColors.statusDanger,
              shape: BoxShape.circle,
              boxShadow: [
                if (isLive)
                  BoxShadow(
                    color: AppColors.statusSafe.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLive ? "ONLINE" : "OFFLINE",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: isLive ? AppColors.statusSafe : AppColors.statusDanger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorSectionHeader(BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 10, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: color.withValues(alpha: 0.2),
               shape: BoxShape.circle,
             ),
             child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                   title,
                   style: TextStyle(
                     fontSize: 16,
                     fontWeight: FontWeight.w600,
                     color: colorScheme.onSurface,
                   ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // --- MOCK DATA CHARTS ---

  Widget _buildTemperatureChart(double currentTemp, bool isLive) {
    // Hide sensor error values (-127) or uninitialized values (0.0) when offline
    final bool isOffline = !isLive;
    final bool hasError = currentTemp == -127.0 || isOffline;
    final String displayTemp = (!hasError) 
        ? '${currentTemp.toStringAsFixed(1)} °C' 
        : '-';

    return Stack(
      children: [
        LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 5,
              getDrawingHorizontalLine: (value) {
                return FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1);
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 6,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      meta: meta,
                      child: Text('${value.toInt()}h', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 10,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      meta: meta,
                      child: Text('${value.toInt()}°C', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: 24,
            minY: 0,
            maxY: math.max(50.0, currentTemp + 10.0),
            lineBarsData: [
              LineChartBarData(
                spots: hasError ? [] : _getMockTempData(currentTemp),
                isCurved: true,
                color: AppColors.primaryBlue,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.5)),
            ),
            child: Text(
              displayTemp,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmokeGauge(BuildContext context, double currentPpm, double threshold) {
    return _PpmGauge(
      value: currentPpm,
      maxValue: 2000.0,
      threshold: threshold,
      unit: 'PPM',
      label: 'Smoke',
      baseColor: AppColors.primaryBlue,
    );
  }

  // --- COMBINED FLAME SENSOR CARD ---
  Widget _buildFlameSensorCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool mainFlameDetected,
    required double backupPpm,
    required double backupThreshold,
    required bool isLive,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // If main flame detects fire, backup should also reflect danger
    // NOTE: Backup Flame uses INVERSE logic (Low PPM = Flame Detected)
    final effectiveBackupDanger = mainFlameDetected || backupPpm <= backupThreshold;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: effectiveBackupDanger
              ? AppColors.statusDanger.withValues(alpha: 0.3)
              : isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveBackupDanger
                ? AppColors.statusDanger.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: effectiveBackupDanger ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.statusDanger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_outlined, color: AppColors.statusDanger, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(isLive),
            ],
          ),
          const SizedBox(height: 16),

          // --- Section 1: Main Sensor ---
          _buildSensorSectionHeader(context, "MAIN SENSOR", Icons.sensors_rounded),
          const SizedBox(height: 6),
          _FlameStatusIndicator(isFlameDetected: mainFlameDetected),
          
          const SizedBox(height: 12),

          // Subtle divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  colorScheme.onSurface.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // --- Section 2: Backup Sensor ---
          _buildSensorSectionHeader(context, "BACKUP SENSOR (PPM)", Icons.settings_input_component_rounded),
          const SizedBox(height: 4),
          Expanded(
            child: _BackupFlameGauge(
              ppm: backupPpm,
              threshold: backupThreshold,
              maxPpm: 4095.0,
              isMainFlameTriggered: mainFlameDetected,
            ),
          ),
        ],
      ),
    );
  }
  




  // --- MOCK DATA GENERATORS ---

  List<FlSpot> _getMockTempData(double currentTemp) {
    // If it's a sensor error value, don't show the line
    if (currentTemp <= -100 || currentTemp == 0.0) return [];
    
    // Generate a flat line for the chart reflecting currentTemp
    return [
      FlSpot(0, currentTemp),
      FlSpot(4, currentTemp),
      FlSpot(8, currentTemp),
      FlSpot(12, currentTemp),
      FlSpot(16, currentTemp),
      FlSpot(20, currentTemp),
      FlSpot(24, currentTemp),
    ];
  }


  

}

// ---------------------------------------------------------------------------
// PPM Arc Gauge Meter
// ---------------------------------------------------------------------------

class _PpmGauge extends StatelessWidget {
  final double value;
  final double maxValue;
  final double threshold;
  final String unit;
  final String label;
  final Color baseColor;
  final bool isInverse;

  const _PpmGauge({
    required this.value,
    required this.maxValue,
    required this.threshold,
    required this.unit,
    required this.label,
    required this.baseColor,
    this.isInverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (value / maxValue).clamp(0.0, 1.0);
    final thresholdRatio = (threshold / maxValue).clamp(0.0, 1.0);

    Color valueColor;
    String statusLabel;

    if (isInverse) {
      if (ratio <= thresholdRatio) {
        valueColor = AppColors.statusDanger;
        statusLabel = 'FLAME DETECTED';
      } else if (ratio <= thresholdRatio * 1.5) {
        valueColor = AppColors.statusWarning;
        statusLabel = 'WARNING';
      } else {
        valueColor = baseColor;
        statusLabel = 'NORMAL';
      }
    } else {
      if (ratio >= thresholdRatio) {
        valueColor = AppColors.statusDanger;
        statusLabel = 'ABOVE LIMIT';
      } else if (ratio >= thresholdRatio * 0.75) {
        valueColor = AppColors.statusWarning;
        statusLabel = 'WARNING';
      } else {
        valueColor = baseColor;
        statusLabel = 'NORMAL';
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: CustomPaint(
            painter: _GaugePainter(
              ratio: ratio,
              maxValue: maxValue,
              thresholdRatio: thresholdRatio,
              baseColor: baseColor,
              valueColor: valueColor,
              isInverse: isInverse,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 28),
                  Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: valueColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: valueColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Limit: ${threshold.toStringAsFixed(0)} PPM',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.statusDanger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double ratio;
  final double maxValue;
  final double thresholdRatio;
  final Color baseColor;
  final Color valueColor;
  final bool isInverse;

  static const double _startDeg = 145.0;
  static const double _sweepDeg = 250.0;

  const _GaugePainter({
    required this.ratio,
    required this.maxValue,
    required this.thresholdRatio,
    required this.baseColor,
    required this.valueColor,
    this.isInverse = false,
  });

  double _rad(double deg) => deg * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.54);
    final radius = math.min(size.width, size.height) * 0.40;
    final strokeW = radius * 0.20;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawArc(
      rect,
      _rad(_startDeg),
      _rad(_sweepDeg),
      false,
      Paint()
        ..color = Colors.grey.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );

    // Safe zone tint
    if (isInverse) {
       // Zone from threshold to max is safe
       canvas.drawArc(
        rect,
        _rad(_startDeg + _sweepDeg * thresholdRatio),
        _rad(_sweepDeg * (1.0 - thresholdRatio)),
        false,
        Paint()
          ..color = baseColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    } else {
      // Zone from 0 to threshold is safe
      if (thresholdRatio > 0) {
        canvas.drawArc(
          rect,
          _rad(_startDeg),
          _rad(_sweepDeg * thresholdRatio),
          false,
          Paint()
            ..color = baseColor.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Gradient value arc drawn in 60 segments
    if (ratio > 0) {
      final valueSweep = _sweepDeg * ratio;
      const segments = 60;
      final segSweep = valueSweep / segments;
      for (int i = 0; i < segments; i++) {
        final t = (i / (segments - 1)).clamp(0.0, 1.0);
        Color segColor;
        
        if (isInverse) {
          if (t < thresholdRatio) {
            segColor = AppColors.statusDanger;
          } else if (t < thresholdRatio * 1.5) {
            segColor = Color.lerp(
              AppColors.statusDanger,
              AppColors.statusWarning,
              (t - thresholdRatio) / (thresholdRatio * 0.5),
            )!;
          } else {
            segColor = Color.lerp(
              AppColors.statusWarning,
              baseColor,
              ((t - thresholdRatio * 1.5) / (1.0 - thresholdRatio * 1.5)).clamp(0.0, 1.0),
            )!;
          }
        } else {
          if (t < thresholdRatio * 0.70) {
            segColor = baseColor;
          } else if (t < thresholdRatio) {
            segColor = Color.lerp(
              baseColor,
              AppColors.statusWarning,
              (t - thresholdRatio * 0.70) / (thresholdRatio * 0.30),
            )!;
          } else {
            segColor = Color.lerp(
              AppColors.statusWarning,
              AppColors.statusDanger,
              ((t - thresholdRatio) / (1.0 - thresholdRatio)).clamp(0.0, 1.0),
            )!;
          }
        }
        canvas.drawArc(
          rect,
          _rad(_startDeg + segSweep * i),
          _rad(segSweep + 0.6),
          false,
          Paint()
            ..color = segColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = i == 0 ? StrokeCap.round : StrokeCap.butt,
        );
      }
    }

    // Threshold tick
    final thAngle = _rad(_startDeg + _sweepDeg * thresholdRatio);
    canvas.drawLine(
      center + Offset((radius - strokeW * 0.6) * math.cos(thAngle), (radius - strokeW * 0.6) * math.sin(thAngle)),
      center + Offset((radius + strokeW * 0.6) * math.cos(thAngle), (radius + strokeW * 0.6) * math.sin(thAngle)),
      Paint()
        ..color = AppColors.statusDanger
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Needle glow + dot
    final needleAngle = _rad(_startDeg + _sweepDeg * ratio);
    final tipX = radius * math.cos(needleAngle);
    final tipY = radius * math.sin(needleAngle);
    final tip = center + Offset(tipX, tipY);

    canvas.drawCircle(
      tip, strokeW * 0.50,
      Paint()
        ..color = valueColor.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(tip, strokeW * 0.38, Paint()..color = valueColor);
    canvas.drawCircle(tip, strokeW * 0.16, Paint()..color = Colors.white);

    // Scale ticks at 0%, 25%, 50%, 75%, 100%
    for (int i = 0; i <= 4; i++) {
      final t = i / 4.0;
      final a = _rad(_startDeg + _sweepDeg * t);
      canvas.drawLine(
        center + Offset((radius - strokeW) * math.cos(a), (radius - strokeW) * math.sin(a)),
        center + Offset((radius - strokeW * 0.45) * math.cos(a), (radius - strokeW * 0.45) * math.sin(a)),
        Paint()
          ..color = Colors.grey.withValues(alpha: 0.45)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // Min/Max Scale Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw "0"
    textPainter.text = TextSpan(
      text: '0',
      style: TextStyle(color: Colors.grey.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    final startAngle = _rad(_startDeg);
    final zeroOffset = center +
        Offset(
          (radius + strokeW * 1.5) * math.cos(startAngle) - textPainter.width / 2,
          (radius + strokeW * 1.5) * math.sin(startAngle) - textPainter.height / 2,
        );
    textPainter.paint(canvas, zeroOffset);

    // Draw maxValue
    textPainter.text = TextSpan(
      text: maxValue.toStringAsFixed(0),
      style: TextStyle(color: Colors.grey.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    final endAngle = _rad(_startDeg + _sweepDeg);
    final maxOffset = center +
        Offset(
          (radius + strokeW * 1.5) * math.cos(endAngle) - textPainter.width / 2,
          (radius + strokeW * 1.5) * math.sin(endAngle) - textPainter.height / 2,
        );
    textPainter.paint(canvas, maxOffset);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.ratio != ratio || old.thresholdRatio != thresholdRatio;
}

// ---------------------------------------------------------------------------
// Combined Flame Sensor Components
// ---------------------------------------------------------------------------

class _FlameStatusIndicator extends StatefulWidget {
  final bool isFlameDetected;
  
  const _FlameStatusIndicator({required this.isFlameDetected});

  @override
  State<_FlameStatusIndicator> createState() => _FlameStatusIndicatorState();
}

class _FlameStatusIndicatorState extends State<_FlameStatusIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isFlameDetected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_FlameStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlameDetected != oldWidget.isFlameDetected) {
      if (widget.isFlameDetected) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isFlameDetected ? AppColors.statusDanger : AppColors.statusSafe;
    final text = widget.isFlameDetected ? 'FLAME DETECTED' : 'NO FLAME DETECTED';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isFlameDetected ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: widget.isFlameDetected ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ] : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupFlameGauge extends StatelessWidget {
  final double ppm;
  final double threshold;
  final double maxPpm;
  final bool isMainFlameTriggered;

  const _BackupFlameGauge({
    required this.ppm,
    required this.threshold,
    required this.maxPpm,
    required this.isMainFlameTriggered,
  });

  @override
  Widget build(BuildContext context) {
    return _PpmGauge(
      value: ppm,
      maxValue: maxPpm,
      threshold: threshold,
      unit: 'PPM',
      label: 'BACKUP ANALYTIC',
      baseColor: AppColors.statusSafe, // Base is safe (greenish)
      isInverse: true,
    );
  }
}
