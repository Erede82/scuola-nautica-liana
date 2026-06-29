import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../data/extra_content_mapper.dart';
import '../data/extra_content_mock.dart';
import '../models/extra_content_item.dart';
import '../repositories/backoffice/management_repository_registry.dart';
import '../services/demo_student_enrollment.dart';
import '../widgets/branded_app_bar_title.dart';
import 'extra_item_detail_page.dart';
import 'extra_my_purchases_page.dart';
import '../theme/app_visual_tokens.dart';

/// Contenuti video extra a pagamento: catalogo con pacchetti da DB (fallback mock).
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

  Future<_ExtraPageData>? _pageDataFuture;

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadPageData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCheckoutReturnQuery();
    });
  }

  void _handleCheckoutReturnQuery() {
    if (!kIsWeb) return;
    final params = Uri.base.queryParameters;
    final checkout = params['extraCheckout'];
    if (checkout == null) return;

    final productId = params['productId'];
    if (checkout == 'success') {
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productId != null
                ? 'Pagamento ricevuto. L’accesso al contenuto si attiva a breve.'
                : 'Pagamento ricevuto. L’accesso si attiva a breve.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (checkout == 'cancel') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pagamento annullato.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<_ExtraPageData> _loadPageData() async {
    final studentId = studentSession.value?.studentId;
    final purchasedIdsFuture = studentId == null
        ? Future<Set<String>>.value(const <String>{})
        : managementRepository.listPurchasedExtraProductIds(studentId);

    List<ExtraContentItem> items;
    try {
      final products = await managementRepository.listExtraProducts();
      if (products.isNotEmpty) {
        items = products.map(ExtraContentMapper.fromProduct).toList();
      } else if (!SupabaseConfig.isConfigured) {
        items = ExtraContentMock.items;
      } else {
        items = ExtraContentMock.items;
      }
    } catch (_) {
      items = ExtraContentMock.items;
    }

    final purchasedIds = await purchasedIdsFuture;
    return _ExtraPageData(items: items, purchasedIds: purchasedIds);
  }

  Future<void> _reload() async {
    setState(() {
      _pageDataFuture = _loadPageData();
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
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const SectionAppBarTitle('Extra', logoHeight: 30),
        shape: const RoundedRectangleBorder(),
        actions: [
          if (studentSession.value?.studentId != null)
            _ExtraPurchasesAppBarAction(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ExtraMyPurchasesPage(),
                  ),
                );
              },
            ),
        ],
      ),
      body: FutureBuilder<_ExtraPageData>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Text('Impossibile caricare il catalogo Extra.'),
            );
          }

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
              ...data.items.map((item) {
                final purchased =
                    item.isUnlocked || data.purchasedIds.contains(item.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExtraLargeCard(
                    item: item,
                    accent: extraCardAccentForProductId(item.id),
                    purchased: purchased,
                    onTap: () => _openDetail(context, item, purchased),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _ExtraPageData {
  const _ExtraPageData({required this.items, required this.purchasedIds});

  final List<ExtraContentItem> items;
  final Set<String> purchasedIds;
}

class _ExtraLargeCard extends StatelessWidget {
  const _ExtraLargeCard({
    required this.item,
    required this.accent,
    required this.purchased,
    required this.onTap,
  });

  final ExtraContentItem item;
  final ExtraCardAccent accent;
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
      case ExtraCardAccent.teoria:
        return BoxDecoration(
          color: const Color(0xFFE8F3F8),
          borderRadius: r,
          border: Border.all(
            color: const Color(0xFF44BBCA).withValues(alpha: 0.25),
          ),
          boxShadow: shadow,
        );
      case ExtraCardAccent.guida:
        return BoxDecoration(
          color: const Color(0xFFE4F0F6),
          borderRadius: r,
          border: Border.all(
            color: const Color(0xFF7EC4D8).withValues(alpha: 0.35),
          ),
          boxShadow: shadow,
        );
      case ExtraCardAccent.carteggio:
        return BoxDecoration(
          color: const Color(0xFFE8F0F5),
          borderRadius: r,
          border: Border.all(
            color: const Color(0xFF44BBCA).withValues(alpha: 0.3),
          ),
          boxShadow: shadow,
        );
      case ExtraCardAccent.pacchetto:
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
    final locked = !purchased && !item.isComingSoon;

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
              ] else if (locked) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8A317).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFFE8A317).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Bloccato',
                    style: textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF9A6B00),
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

/// App bar action: icon-only su viewport stretti per evitare overflow.
class _ExtraPurchasesAppBarAction extends StatelessWidget {
  const _ExtraPurchasesAppBarAction({required this.onPressed});

  static const double _compactBreakpoint = 380;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < _compactBreakpoint;

    if (narrow) {
      return IconButton(
        onPressed: onPressed,
        tooltip: 'I miei acquisti',
        icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
        label: const Text(
          'I miei acquisti',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
