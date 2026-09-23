import 'package:flutter/material.dart';

import '../app_info.dart';
import '../app_scope.dart';
import '../data/store.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';
import '../ui/glow.dart';
import '../ui/logo.dart';

/// Settings hub, redesigned as clean card containers: each card has a soft
/// shadow, rounded corners, generous padding, an icon tile per row, and a
/// custom accessible switch. Typography hierarchy: small-caps section
/// headers → bold row titles → muted one-line descriptions.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ---- Preferences -----------------------------------------------
          const _SectionLabel('Preferences'),
          _SettingsCard(
            children: [
              _SwitchRow(
                icon: app.darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                tileColor: const Color(0xFF5C6BC0),
                title: 'Dark mode',
                description: app.darkMode
                    ? 'On — a night-kitchen glow'
                    : 'Off — bright, crisp and clean',
                value: app.darkMode,
                onChanged: (_) => app.toggleDarkMode(),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Icons.auto_awesome_rounded,
                tileColor: const Color(0xFF00ACC1),
                title: 'Glow effects',
                description: app.glowEffects
                    ? 'Icons light up their surroundings'
                    : 'Flat icons — calm and battery-friendly',
                value: app.glowEffects,
                onChanged: (_) => app.toggleGlowEffects(),
              ),
              const _RowDivider(),
              _SwitchRow(
                icon: Icons.celebration_rounded,
                tileColor: AppTheme.terracotta,
                title: 'Celebrations',
                description: 'Confetti when you finish the list',
                value: app.celebrationsOn,
                onChanged: (_) => app.toggleCelebrations(),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ---- About ------------------------------------------------------
          const _SectionLabel('About'),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const RecipePilotLogo(size: 56),
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
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(icon: Icons.wifi_off, label: '100% offline'),
                      _Chip(icon: Icons.lock_outline, label: 'Data stays on device'),
                      _Chip(icon: Icons.bolt, label: 'No ads'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ---- Data -------------------------------------------------------
          const _SectionLabel('Your data'),
          _SettingsCard(
            children: [
              _ActionRow(
                icon: Icons.restart_alt_rounded,
                tileColor: AppTheme.checkGreen,
                title: 'Reset checked items',
                description: 'Uncheck everything on the current list',
                onTap: () {
                  app.resetChecked();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All items unchecked')),
                  );
                },
              ),
              const _RowDivider(),
              _ActionRow(
                icon: Icons.delete_sweep_rounded,
                tileColor: scheme.error,
                destructive: true,
                title: 'Clear grocery list',
                description: 'Removes the current list (recipes are kept)',
                onTap: () => _confirmClear(context, app),
              ),
            ],
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

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

/// Card container: soft shadow, rounded-xl equivalent, tight vertical rhythm.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({this.child, this.children});

  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        boxShadow: [
          // shadow-sm equivalent; nearly invisible in dark mode by design.
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child ??
          (children != null
              ? Column(children: children!)
              : const SizedBox.shrink()),
    );
  }
}

/// Base row: colorful icon tile + title + muted description.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.tileColor,
    required this.title,
    required this.description,
    this.destructive = false,
  });

  final IconData icon;
  final Color tileColor;
  final String title;
  final String description;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GlowTile(
            color: tileColor,
            size: 40,
            radius: 12,
            child: GlowIcon(icon: icon, color: tileColor, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: destructive ? scheme.error : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch row with a custom, accessible toggle: labelled, toggleable by
/// tapping the whole row (Semantics →Switch, so screen readers announce it),
/// with an animated thumb/track and the label dimming when off.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.tileColor,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color tileColor;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      toggled: value,
      label: title,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(
              child: _SettingsRow(
                icon: icon,
                tileColor: tileColor,
                title: title,
                description: description,
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: value ? 1.0 : 0.55,
              child: Switch(value: value, onChanged: onChanged),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Tap-through row for destructive/data actions, with a chevron affordance.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.tileColor,
    required this.title,
    required this.description,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final Color tileColor;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: _SettingsRow(
              icon: icon,
              tileColor: tileColor,
              title: title,
              description: description,
              destructive: destructive,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.35)),
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

/// Hairline between rows inside a card, aligned with the text column.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 70),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.5),
      ),
    );
  }
}
