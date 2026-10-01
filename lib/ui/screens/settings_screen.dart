import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/alert_providers.dart';
import '../../providers/auth_provider.dart';
import '../../app.dart' show themeModeProvider;
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.person_outline, color: AppColors.gold),
              ),
              title: Text(user?.email ?? 'Signed in'),
              subtitle: const Text('Firebase Authentication'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Appearance'),
              subtitle: const Text('Light, dark, or follow system'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                    label: Text('Light')),
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_suggest_outlined, size: 18),
                    label: Text('Auto')),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                    label: Text('Dark')),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.notifications_outlined),
              title: Text('Push notifications'),
              subtitle: Text('Managed by the app — alerts are evaluated on the '
                  'server, so notifications arrive even when the app is closed.'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('Prune old history'),
              subtitle: const Text('Delete trigger records older than 90 days'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final svc = ref.read(firestoreServiceProvider);
                if (svc == null) return;
                final deleted = await svc.pruneHistory();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(deleted == 0
                      ? 'Nothing to prune.'
                      : 'Deleted $deleted old records.')),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              onPressed: () async {
                await NotificationService.unregisterForCurrentUser();
                await ref.read(authServiceProvider).signOut();
              },
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Alerto v0.1.0',
                style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
