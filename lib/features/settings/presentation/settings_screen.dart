import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nextarc/core/providers/theme_provider.dart';
import 'package:nextarc/features/watchlist/domain/guest_watchlist_providers.dart';
import 'package:share_plus/share_plus.dart';

/// Écran Paramètres — accessible depuis le profil.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final repo = ref.read(guestWatchlistRepositoryProvider);
      final jsonStr = await repo.exportJson();
      await Share.share(
        jsonStr,
        subject: 'NextArc — Ma watchlist',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _import() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final jsonStr = String.fromCharCodes(bytes);
      await ref.read(guestWatchlistRepositoryProvider).importJson(jsonStr);
      ref.invalidate(guestWatchlistProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Liste importée avec succès ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur import : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            subtitle: 'Noir et bleu denim foncé',
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

          // ── Liste locale ─────────────────────────────────────────────────────
          _SectionHeader(label: 'Liste locale (mode invité)'),

          ListTile(
            leading: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.upload_rounded, color: cs.primary),
            title: const Text('Exporter ma liste'),
            subtitle: Text(
              'Partager la watchlist locale en JSON',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.54)),
            ),
            onTap: _isExporting ? null : _export,
          ),

          ListTile(
            leading: _isImporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.download_rounded, color: cs.primary),
            title: const Text('Importer une liste'),
            subtitle: Text(
              'Charger une watchlist depuis un fichier .json',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withValues(alpha: 0.54)),
            ),
            onTap: _isImporting ? null : _import,
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
        color: selected
            ? cs.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? cs.primary.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        leading: Icon(icon,
            color: selected
                ? cs.primary
                : cs.onSurface.withValues(alpha: 0.5)),
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
