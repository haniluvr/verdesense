import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/page_title.dart';
import '../../../../core/providers/user_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../../../core/services/activity_log_service.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int activeIndex;
  const SettingsScreen({super.key, this.activeIndex = 4});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          key: ValueKey('Page_${widget.activeIndex}'),
          title: "Settings"
        ),
        const SizedBox(height: 24),
        // Settings Content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            _buildSectionHeader("Account"),
            _buildSettingsTile(
              icon: Icons.person_outline,
              title: "Profile Details",
              subtitle: "Admin",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
            
            const SizedBox(height: 24),
            // Preferences Section
            _buildSectionHeader("Preferences"),


            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return _buildSwitchTile(
                  icon: themeProvider.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  title: "Dark Mode",
                  subtitle: themeProvider.isDarkMode ? "Enabled" : "Disabled",
                  value: themeProvider.isDarkMode,
                  onChanged: (val) {
                    themeProvider.toggleTheme();
                  },
                );
              }
            ),

            const SizedBox(height: 24),
            // Support & About Section
            _buildSectionHeader("About"),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: "About CrowdSense",
              subtitle: "Version 1.0.0",
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const _AboutCrowdSenseSheet(),
                );
              },
            ),

            const SizedBox(height: 32),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Log Out"),
                        content: const Text("Log out of your account?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              // Capture email BEFORE clearing user state
                              final email = context.read<UserProvider>().email ?? '';
                              if (context.mounted) {
                                await context.read<UserProvider>().clearUser();
                              }
                              ActivityLogService.logUserLogout(email: email);
                              await AuthService().logout();
                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/login',
                                  (route) => false,
                                );
                              }
                            },
                            child: const Text(
                              "Log Out",
                              style: TextStyle(color: AppColors.statusDanger),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.logout, color: AppColors.statusDanger),
                label: const Text(
                  "Log Out",
                  style: TextStyle(color: AppColors.statusDanger, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.statusDanger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 48), // Bottom padding
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: isDark ? 10 : 20,
            offset: Offset(0, isDark ? 4 : 8),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colorScheme.secondary, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              )
            : null,
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: isDark ? 10 : 20,
            offset: Offset(0, isDark ? 4 : 8),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        activeColor: colorScheme.secondary,
        activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
        inactiveThumbColor: colorScheme.onSurfaceVariant,
        inactiveTrackColor: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: value ? colorScheme.primary.withValues(alpha: 0.1) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon, 
            color: value ? colorScheme.secondary : colorScheme.onSurfaceVariant, 
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              )
            : null,
      ),
    );
  }
}

class _AboutCrowdSenseSheet extends StatelessWidget {
  const _AboutCrowdSenseSheet();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
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
                          'assets/images/crowdsense_logo.png',
                          width: 64,
                          height: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Title ---
                    Center(
                      child: Text(
                        "About CrowdSense",
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
                        "Version 1.0.0  •  © 2026 CrowdSense Project",
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Intro ---
                    _AboutBody(
                      text: "CrowdSense: Intelligent Crowd Monitoring and Emergency Alert System is a specialized IoT-driven platform designed to enhance safety and situational awareness within high-density environments.\n\nDeveloped specifically for the Polytechnic University of the Philippines – College of Engineering and Architecture (CEA) Building, this system integrates real-time environmental monitoring with crowd density analytics to provide a proactive approach to emergency management.",
                    ),
                    const SizedBox(height: 24),

                    // --- Technology Section ---
                    _AboutSectionHeader(title: "The Technology", icon: Icons.memory_rounded),
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
                    _AboutSectionHeader(title: "Our Mission", icon: Icons.flag_rounded),
                    const SizedBox(height: 12),
                    _AboutBody(
                      text: "Our goal is to leverage Computer Engineering principles to transform traditional building management into an \"intelligent\" ecosystem. By providing real-time data trends and automated alerts, CrowdSense empowers facility managers and occupants with the information needed to navigate emergencies safely.",
                    ),
                    const SizedBox(height: 24),

                    // --- Research Team ---
                    _AboutSectionHeader(title: "The Research Team", icon: Icons.group_rounded),
                    const SizedBox(height: 12),
                    _AboutBody(
                      text: "We are a dedicated group of 4th-year BS Computer Engineering students from the Polytechnic University of the Philippines, committed to innovating public safety through technology.",
                    ),
                    const SizedBox(height: 12),
                    _TeamMemberCard(name: "Carl Patrick M. Ragas", colorScheme: colorScheme, isDark: isDark),
                    const SizedBox(height: 8),
                    _TeamMemberCard(name: "Hendrix Justine L. Llarinas", colorScheme: colorScheme, isDark: isDark),
                    const SizedBox(height: 8),
                    _TeamMemberCard(name: "Katrice Yvan V. Noval", colorScheme: colorScheme, isDark: isDark),
                    const SizedBox(height: 8),
                    _TeamMemberCard(name: "Kyle Francis B. Trapal", colorScheme: colorScheme, isDark: isDark),
                    const SizedBox(height: 16),

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
                          Text("Department of Computer Engineering",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text("College of Engineering and Architecture",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text("Polytechnic University of the Philippines",
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
              ),
            ],
          ),
        );
      },
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

