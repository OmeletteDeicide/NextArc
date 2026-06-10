import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/providers/theme_provider.dart';

/// Écran Paramètres — accessible depuis le profil.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          // ── Apparence ───────────────────────────────────────────────────────
          _SectionHeader(label: 'Apparence'),

          _ThemeOption(
            icon: Icons.brightness_auto_rounded,
            title: 'Système',
            subtitle: 'Suit le mode de ton téléphone',
            selected: currentMode == ThemeMode.system,
            onTap: () =>
                ref.read(themeProvider.notifier).setTheme(ThemeMode.system),
          ),

          _ThemeOption(
            icon: Icons.dark_mode_rounded,
            title: 'Mode sombre',
            subtitle: 'Nori et bleu denim foncé',
            selected: currentMode == ThemeMode.dark,
            onTap: () =>
                ref.read(themeProvider.notifier).setTheme(ThemeMode.dark),
          ),

          _ThemeOption(
            icon: Icons.light_mode_rounded,
            title: 'Mode clair',
            subtitle: 'Blanc doux et bleu denim',
            selected: currentMode == ThemeMode.light,
            onTap: () =>
                ref.read(themeProvider.notifier).setTheme(ThemeMode.light),
          ),

          const SizedBox(height: 8),
          Divider(color: cs.outline.withValues(alpha: 0.2)),
          const SizedBox(height: 8),

          // ── À propos ────────────────────────────────────────────────────────
          _SectionHeader(label: 'Application'),

          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: cs.primary),
            title: const Text('Version'),
            trailing: Text(
              '1.0.0',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: cs.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? cs.primary.withValues(alpha: 0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        leading: Icon(icon, color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? cs.primary : cs.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: cs.primary, size: 20)
            : null,
      ),
    );
  }
}
