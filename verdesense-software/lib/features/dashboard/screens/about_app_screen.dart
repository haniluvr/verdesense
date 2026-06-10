import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 12),

          // --- Logo ---
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/VerdeSense_logo.png',
                width: 64,
                height: 64,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Title ---
          Center(
            child: Text(
              "About VerdeSense",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Version 1.0.0  •  © 2026 VerdeSense Project",
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),

          // --- Intro ---
          const _AboutBody(
            text: "VerdeSense is an integrated Internet of Things (IoT) and cloud-based ecosystem designed to monitor safety and occupancy in controlled agricultural greenhouses. The system actively detects environmental hazards such as smoke, gas, and fire in real-time, while simultaneously tracking the number of personnel inside the greenhouse to ensure safety and operational efficiency.\n\nBy combining an ESP32-based hardware node with a cross-platform Flutter application and Firebase cloud infrastructure, VerdeSense provides automated local sirens, real-time dashboards, and robust historical data logging.",
          ),
          const SizedBox(height: 24),

          // --- Technology Section ---
          const _AboutSectionHeader(title: "The Technology", icon: Icons.memory_rounded),
          const SizedBox(height: 12),
          _AboutFeatureCard(
            icon: Icons.sensors,
            title: "Time-of-Flight (ToF) Sensors",
            description: "High-precision, non-intrusive crowd counting and flow analysis.",
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 8),
          _AboutFeatureCard(
            icon: Icons.local_fire_department_rounded,
            title: "Flame & Smoke Detection",
            description: "Instantaneous detection of fire hazards to minimize response time.",
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 8),
          _AboutFeatureCard(
            icon: Icons.thermostat_rounded,
            title: "Temperature Monitoring",
            description: "Continuous thermal tracking to identify abnormal heat patterns before they escalate.",
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 8),
          _AboutFeatureCard(
            icon: Icons.cloud_done_rounded,
            title: "Firebase Cloud Server",
            description: "Real-time data synchronization and secure cloud storage using Firebase Realtime Database.",
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 8),
          _AboutFeatureCard(
            icon: Icons.flutter_dash_rounded,
            title: "Flutter Framework",
            description: "Modern, cross-platform application built with the Flutter SDK for a premium user experience.",
            isDark: isDark,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 24),

          // --- Mission Section ---
          const _AboutSectionHeader(title: "Our Mission", icon: Icons.flag_rounded),
          const SizedBox(height: 12),
          const _AboutBody(
            text: "Our goal is to leverage Computer Engineering principles to transform traditional building management into an \"intelligent\" ecosystem. By providing real-time data trends and automated alerts, VerdeSense empowers facility managers and occupants with the information needed to navigate emergencies safely.",
          ),
          const SizedBox(height: 24),

          // --- Research Team ---
          const _AboutSectionHeader(title: "The Research Team", icon: Icons.group_rounded),
          const SizedBox(height: 12),
          const _AboutBody(
            text: "We are a dedicated group of 3rd-year BS Information Technology students from the Technological Institute of the Philippines, committed to innovating public safety through technology.",
          ),
          const SizedBox(height: 12),
          _TeamMemberCard(name: "Hannah Ysabelle C. Marquez", colorScheme: colorScheme, isDark: isDark),
          const SizedBox(height: 8),
          _TeamMemberCard(name: "Ian Darick S. Alcantara", colorScheme: colorScheme, isDark: isDark),
          const SizedBox(height: 8),
          _TeamMemberCard(name: "Alex Arthur P. Enzon", colorScheme: colorScheme, isDark: isDark),
          const SizedBox(height: 8),
          _TeamMemberCard(name: "Gabriel Ellis P. Muega", colorScheme: colorScheme, isDark: isDark),
          const SizedBox(height: 8),
          _TeamMemberCard(name: "Christian James N. Vergara", colorScheme: colorScheme, isDark: isDark),
          const SizedBox(height: 8),

          // --- Affiliation ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Text("Department of Information Technology",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 13)),
                const SizedBox(height: 2),
                Text("College of Computer Studies",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 2),
                Text("Technological Institute of the Philippines",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // --- Documentation Button ---
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {}, // Placeholder
              icon: Icon(Icons.article_outlined, color: colorScheme.primary),
              label: Text(
                "View Technical Documentation",
                style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _AboutSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _AboutSectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _AboutBody extends StatelessWidget {
  final String text;
  const _AboutBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.65,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _AboutFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDark;
  final ColorScheme colorScheme;

  const _AboutFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 13)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final String name;
  final ColorScheme colorScheme;
  final bool isDark;

  const _TeamMemberCard({required this.name, required this.colorScheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface)),
        ],
      ),
    );
  }
}
