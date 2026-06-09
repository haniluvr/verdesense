import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final int activeIndex;
  final List<Map<String, dynamic>> deviceData;
  const MapScreen({super.key, this.activeIndex = 1, this.deviceData = const []});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  void _showSensorDetails(BuildContext context, Map<String, dynamic> zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDanger = zone['isDanger'] == true;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textGrey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDanger ? AppColors.statusDanger.withValues(alpha: 0.2) : AppColors.primaryRose.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDanger ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: isDanger ? AppColors.statusDanger : AppColors.primaryRose,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone['name'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDanger ? "Critical Alert" : "Operating Normally",
                            style: TextStyle(
                              fontSize: 14,
                              color: isDanger ? AppColors.statusDanger : AppColors.primaryRose,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Sensor readings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomSheetMetric(Icons.thermostat, "${zone['temperature']}°C", "Temp"),
                    _buildBottomSheetMetric(Icons.water_drop, "N/A", "Humidity"),
                    _buildBottomSheetMetric(Icons.air, "${zone['gas']}", "Gas (PPM)"),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetMetric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textGrey, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textLight,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.textLight),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = const LatLng(14.5985, 121.0051);
    final mappedZones = widget.deviceData.asMap().entries.map((entry) {
      final idx = entry.key;
      final device = entry.value;
      return {
        'name': device['location'] ?? 'Unknown Node',
        'location': LatLng(center.latitude + (idx * 0.0003), center.longitude + (idx * 0.0002)),
        'isDanger': device['isDanger'] == true,
        'temperature': device['temperature'] ?? 0.0,
        'gas': device['gas'] ?? 0,
      };
    }).toList();

    return Stack(
      children: [
        // Leaflet Map Container
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(14.5985, 121.0051),
              initialZoom: 17.5,
              maxZoom: 20.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.verdesense.app',
              ),
              MarkerLayer(
                markers: mappedZones.map((zone) {
                  final isDanger = zone['isDanger'] == true;
                  return Marker(
                    point: zone['location'] as LatLng,
                    width: 120,
                    height: 100,
                    child: GestureDetector(
                      onTap: () => _showSensorDetails(context, zone),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDanger 
                                ? AppColors.statusDanger.withValues(alpha: 0.4) 
                                : AppColors.primaryRose.withValues(alpha: 0.2),
                              border: Border.all(
                                color: isDanger ? AppColors.statusDanger : AppColors.primaryRose,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDanger ? AppColors.statusDanger : AppColors.primaryRose,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceDark.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDanger ? AppColors.statusDanger.withValues(alpha: 0.5) : AppColors.borderDark,
                              ),
                            ),
                            child: Text(
                              zone['name'],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Zoom Controls
        Positioned(
          right: 16,
          bottom: 120, // above the bottom nav bar
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomButton(Icons.add, () {
                final currentZoom = _mapController.camera.zoom;
                _mapController.move(_mapController.camera.center, currentZoom + 1);
              }),
              const SizedBox(height: 12),
              _buildZoomButton(Icons.remove, () {
                final currentZoom = _mapController.camera.zoom;
                _mapController.move(_mapController.camera.center, currentZoom - 1);
              }),
            ],
          ),
        ),

        // Overlay Header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: AppColors.primaryRose, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  "Farm Overview",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Live sensor locations",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                        
                        // Alert Badge (if active)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.statusDanger.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: AppColors.statusDanger.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.statusDanger, size: 14),
                              const SizedBox(width: 4),
                              const Text(
                                "DANGER ZONE",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.statusDanger,
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
        ),
      ],
    );
  }
}

