import 'package:flutter/material.dart';

import '../app_info.dart';
import '../app_scope.dart';
import '../data/store.dart';
import '../ui/animations.dart';

/// Settings hub: appearance, about, and data controls. Reached from the ⚙️
/// corner on the home screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StaggeredEntrance(
        index: 0,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ---- Appearance ----
            _SectionLabel('Appearance'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      app.darkMode ? Icons.dark_mode : Icons.light_mode,
                      color: scheme.primary,
                    ),
                    title: const Text('Dark mode'),
                    subtitle: Text(
                      app.darkMode ? 'On — easy on night eyes' : 'Off — bright and clean',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: app.darkMode,
                    onChanged: (_) => app.toggleDarkMode(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- About ----
            _SectionLabel('About'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text('🥬', style: TextStyle(fontSize: 28)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(appName,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              Text('v$appVersion',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface.withValues(alpha: 0.55),
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      appDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.75),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Chip(icon: Icons.wifi_off, label: '100% offline'),
                        const SizedBox(width: 8),
                        _Chip(icon: Icons.lock_outline, label: 'Data stays on device'),
                        const SizedBox(width: 8),
                        _Chip(icon: Icons.bolt, label: 'No ads'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---- Data ----
            _SectionLabel('Your data'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.restart_alt, color: scheme.primary),
                    title: const Text('Reset checked items'),
                    subtitle: Text(
                      'Uncheck everything on the current list',
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () {
                      app.resetChecked();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All items unchecked')),
                      );
                    },
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.delete_sweep_outlined,
                        color: scheme.error),
                    title: Text('Clear grocery list',
                        style: TextStyle(color: scheme.error)),
                    subtitle: Text(
                      'Removes the current list (recipes are kept)',
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () => _confirmClear(context, app),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Made with 💚 for offline-first cooking',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context, AppController app) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear grocery list?'),
        content: const Text(
          'The current shopping list will be removed. Your saved recipes stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () {
              app.clearAll();
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grocery list cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onPrimaryContainer),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}
