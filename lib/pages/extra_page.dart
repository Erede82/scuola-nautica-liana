import 'package:flutter/material.dart';

import '../data/extra_content_mock.dart';
import '../models/extra_content_item.dart';
import '../repositories/backoffice/management_repository_registry.dart';
import '../services/demo_student_enrollment.dart';
import '../widgets/branded_app_bar_title.dart';
import 'extra_item_detail_page.dart';
import '../theme/app_visual_tokens.dart';

/// Contenuti video extra a pagamento: catalogo con quattro pacchetti principali.
class ExtraPage extends StatefulWidget {
  const ExtraPage({super.key});

  @override
  State<ExtraPage> createState() => _ExtraPageState();
}

class _ExtraPageState extends State<ExtraPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const String _introText =
      'Contenuti video extra per la preparazione nautica. Scegli un pacchetto o il bundle completo.';

  Future<Set<String>>? _purchasedIdsFuture;

  @override
  void initState() {
    super.initState();
    _purchasedIdsFuture = _loadPurchasedIds();
  }

  Future<Set<String>> _loadPurchasedIds() async {
    final studentId = studentSession.value?.studentId;
    if (studentId == null) {
      return const <String>{};
    }
    return managementRepository.listPurchasedExtraProductIds(studentId);
  }

  Future<void> _reloadPurchasedIds() async {
    setState(() {
      _purchasedIdsFuture = _loadPurchasedIds();
    });
  }

  Future<void> _openDetail(
    BuildContext context,
    ExtraContentItem item,
    bool purchased,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ExtraItemDetailPage(item: item, initiallyPurchased: purchased),
      ),
    );
    if (!mounted) return;
    await _reloadPurchasedIds();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = ExtraContentMock.items;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const SectionAppBarTitle('Extra', logoHeight: 30),
        shape: const RoundedRectangleBorder(),
      ),
      body: FutureBuilder<Set<String>>(
        future: _purchasedIdsFuture,
        builder: (context, snapshot) {
          final purchasedIds = snapshot.data ?? const <String>{};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                _introText,
                style: textTheme.bodyMedium?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.9),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _ExtraLargeCard(
                item: items[0],
                accent: _ExtraCardAccent.teoria,
                purchased:
                    items[0].isUnlocked || purchasedIds.contains(items[0].id),
                onTap: () => _openDetail(
                  context,
                  items[0],
                  items[0].isUnlocked || purchasedIds.contains(items[0].id),
                ),
              ),
              const SizedBox(height: 12),
              _ExtraLargeCard(
                item: items[1],
                accent: _ExtraCardAccent.guida,
                purchased:
                    items[1].isUnlocked || purchasedIds.contains(items[1].id),
                onTap: () => _openDetail(
                  context,
                  items[1],
                  items[1].isUnlocked || purchasedIds.contains(items[1].id),
                ),
              ),
              const SizedBox(height: 12),
              _ExtraLargeCard(
                item: items[2],
                accent: _ExtraCardAccent.carteggio,
                purchased:
                    items[2].isUnlocked || purchasedIds.contains(items[2].id),
                onTap: () => _openDetail(
                  context,
                  items[2],
                  items[2].isUnlocked || purchasedIds.contains(items[2].id),
                ),
              ),
              const SizedBox(height: 12),
              _ExtraLargeCard(
                item: items[3],
                accent: _ExtraCardAccent.pacchetto,
                purchased:
                    items[3].isUnlocked || purchasedIds.contains(items[3].id),
                onTap: () => _openDetail(
                  context,
                  items[3],
                  items[3].isUnlocked || purchasedIds.contains(items[3].id),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _ExtraCardAccent { teoria, guida, carteggio, pacchetto }

class _ExtraLargeCard extends StatelessWidget {
  const _ExtraLargeCard({
    required this.item,
    required this.accent,
    required this.purchased,
    required this.onTap,
  });

  final ExtraContentItem item;
  final _ExtraCardAccent accent;
  final bool purchased;
  final VoidCallback onTap;

  static const Color _textPrimary = AppVisual.ink;
  static const Color _primary = AppVisual.logoBlue;

  BoxDecoration _decoration() {
    const r = BorderRadius.all(Radius.circular(16));
    const shadow = [
      BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3)),
    ];
    switch (accent) {
      case _ExtraCardAccent.teoria:
        return BoxDecoration(
          color: const Color(0xFFE8F3F8),
          borderRadius: r,
          border: Border.all(
            color: const Color(0xFF44BBCA).withValues(alpha: 0.25),
          ),
          boxShadow: shadow,
        );
      case _ExtraCardAccent.guida:
        return BoxDecoration(
          color: const Color(0xFFE4F0F6),
          borderRadius: r,
          border: Border.all(
            color: const Color(0xFF7EC4D8).withValues(alpha: 0.35),
          ),
          boxShadow: shadow,
        );
      case _ExtraCardAccent.carteggio:
        return BoxDecoration(
          color: const Color(0xFFE8F0F5),
          borderRadius: r,
          border: Border.all(
            color: const Color(0xFF44BBCA).withValues(alpha: 0.3),
          ),
          boxShadow: shadow,
        );
      case _ExtraCardAccent.pacchetto:
        return BoxDecoration(
          borderRadius: r,
          border: Border.all(
            color: const Color(0xFF17A1C8).withValues(alpha: 0.45),
            width: 1.4,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2F9), Color(0xFFEBF4FA), Color(0xFFD4E8F0)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A17A1C8),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: _decoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: textTheme.titleMedium?.copyWith(
                  color: _textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (purchased) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E9E5B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF2E9E5B).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Acquistato',
                    style: textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF1F7A45),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                item.subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: _textPrimary.withValues(alpha: 0.82),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    item.priceLabel ?? '—',
                    style: textTheme.titleSmall?.copyWith(
                      color: _primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(purchased ? 'Guarda' : 'Acquista'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
