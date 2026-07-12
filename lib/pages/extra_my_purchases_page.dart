import 'package:flutter/material.dart';

import '../constants/extra_content_ids.dart';
import '../data/extra_content_mapper.dart';
import '../domain/backoffice/backoffice.dart';
import '../repositories/backoffice/management_repository_registry.dart';
import '../services/demo_student_enrollment.dart';
import '../pages/student_area_preview_blocked_page.dart';
import '../services/student_area_context.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';
import '../widgets/app_empty_state.dart';
import 'extra_item_detail_page.dart';

/// Elenco acquisti Extra dell'allievo (lettura da `student_extra_purchases`).
class ExtraMyPurchasesPage extends StatefulWidget {
  const ExtraMyPurchasesPage({super.key});

  @override
  State<ExtraMyPurchasesPage> createState() => _ExtraMyPurchasesPageState();
}

class _ExtraMyPurchasesPageState extends State<ExtraMyPurchasesPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  Future<_PurchasesPageData>? _pageDataFuture;

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadPageData();
  }

  Future<_PurchasesPageData> _loadPageData() async {
    final studentId = studentSession.value?.studentId;
    if (studentId == null) {
      throw StateError('student_session_missing');
    }

    final results = await Future.wait<Object>([
      managementRepository.listStudentExtraPurchases(studentId),
      managementRepository.listExtraProducts(),
    ]);

    final purchases = results[0] as List<StudentExtraPurchase>;
    final products = results[1] as List<ExtraProduct>;
    final productById = {for (final p in products) p.id: p};

    return _PurchasesPageData(purchases: purchases, productById: productById);
  }

  Future<void> _reload() async {
    setState(() {
      _pageDataFuture = _loadPageData();
    });
  }

  void _openProduct(ExtraProduct product) {
    final item = ExtraContentMapper.fromProduct(product);
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ExtraItemDetailPage(item: item, initiallyPurchased: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (StudentAreaContext.blocksWrites(context)) {
      return const StudentAreaPreviewBlockedPage(
        title: 'I miei acquisti',
        message: 'Non disponibile in modalità anteprima.',
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('I miei acquisti'),
        shape: const RoundedRectangleBorder(),
      ),
      body: FutureBuilder<_PurchasesPageData>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossibile caricare i tuoi acquisti. Verifica accesso e riprova.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.85),
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null || data.purchases.isEmpty) {
            return AppEmptyState(
              title: 'Non hai ancora acquisti Extra',
              message:
                  'Quando acquisti un videocorso premium, lo troverai qui con data, '
                  'importo e riferimento ordine.',
              icon: Icons.receipt_long_outlined,
              primaryActionLabel: 'Esplora Extra',
              onPrimaryActionPressed: () => Navigator.maybePop(context),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            color: _primaryColor,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: data.purchases.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final purchase = data.purchases[index];
                        final product = data.productById[purchase.productId];
                        return _PurchaseCard(
                          purchase: purchase,
                          productTitle: product?.title ?? purchase.productId,
                          productActive: product?.active ?? false,
                          onWatch: product != null && purchase.unlocksContent
                              ? () => _openProduct(product)
                              : null,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PurchasesPageData {
  const _PurchasesPageData({
    required this.purchases,
    required this.productById,
  });

  final List<StudentExtraPurchase> purchases;
  final Map<String, ExtraProduct> productById;
}

enum _PurchaseAccessKind {
  purchased,
  bundleIncluded,
  staffGranted,
  revoked,
  refunded,
  pending,
}

abstract final class _PurchaseDisplay {
  static _PurchaseAccessKind accessKind(StudentExtraPurchase purchase) {
    switch (purchase.status) {
      case StudentExtraPurchaseStatus.revoked:
        return _PurchaseAccessKind.revoked;
      case StudentExtraPurchaseStatus.refunded:
        return _PurchaseAccessKind.refunded;
      case StudentExtraPurchaseStatus.pending:
        return _PurchaseAccessKind.pending;
      case StudentExtraPurchaseStatus.purchased:
        final ref = purchase.paymentReference?.trim();
        if (purchase.recordedByStaffId != null &&
            (ref == null || ref.isEmpty)) {
          return _PurchaseAccessKind.staffGranted;
        }
        if (purchase.orderProductId == ExtraContentIds.extraPacchetto &&
            purchase.productId != ExtraContentIds.extraPacchetto) {
          return _PurchaseAccessKind.bundleIncluded;
        }
        return _PurchaseAccessKind.purchased;
    }
  }

  static String statusLabel(_PurchaseAccessKind kind) {
    return switch (kind) {
      _PurchaseAccessKind.purchased => 'Acquistato',
      _PurchaseAccessKind.bundleIncluded => 'Incluso nel pacchetto',
      _PurchaseAccessKind.staffGranted => 'Abilitato dalla scuola',
      _PurchaseAccessKind.revoked => 'Revocato',
      _PurchaseAccessKind.refunded => 'Rimborsato',
      _PurchaseAccessKind.pending => 'In elaborazione',
    };
  }

  static Color statusColor(_PurchaseAccessKind kind) {
    return switch (kind) {
      _PurchaseAccessKind.purchased ||
      _PurchaseAccessKind.bundleIncluded ||
      _PurchaseAccessKind.staffGranted => const Color(0xFF1F7A45),
      _PurchaseAccessKind.pending => const Color(0xFF9A6B00),
      _PurchaseAccessKind.revoked ||
      _PurchaseAccessKind.refunded => const Color(0xFF8A4B4B),
    };
  }

  static Color statusBackground(_PurchaseAccessKind kind) {
    return statusColor(kind).withValues(alpha: 0.12);
  }

  static String amountLabel(StudentExtraPurchase purchase) {
    if (accessKind(purchase) == _PurchaseAccessKind.bundleIncluded) {
      return 'Incluso';
    }
    final cents = purchase.amountCents;
    if (cents == null) return '—';
    final euros = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    return '€ $euros';
  }

  static String orderReferenceLabel(StudentExtraPurchase purchase) {
    final code = purchase.orderCode?.trim();
    if (code != null && code.isNotEmpty) return code;
    final ref = purchase.paymentReference?.trim();
    if (ref != null && ref.isNotEmpty) {
      if (ref.length <= 12) return ref;
      return '${ref.substring(0, 8)}…';
    }
    return 'Ordine non disponibile';
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({
    required this.purchase,
    required this.productTitle,
    required this.productActive,
    this.onWatch,
  });

  final StudentExtraPurchase purchase;
  final String productTitle;
  final bool productActive;
  final VoidCallback? onWatch;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final kind = _PurchaseDisplay.accessKind(purchase);
    final muted =
        kind == _PurchaseAccessKind.revoked ||
        kind == _PurchaseAccessKind.refunded;
    final showWatch = onWatch != null && productActive && !muted;

    return Opacity(
      opacity: muted ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _PurchaseCard._cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _PurchaseCard._neutralColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              productTitle,
              style: textTheme.titleMedium?.copyWith(
                color: _PurchaseCard._textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _PurchaseDisplay.statusBackground(kind),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _PurchaseDisplay.statusColor(
                    kind,
                  ).withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                _PurchaseDisplay.statusLabel(kind),
                style: textTheme.labelSmall?.copyWith(
                  color: _PurchaseDisplay.statusColor(kind),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MetaRow(
              label: 'Data acquisto',
              value: GuidaDateTimeFormat.formatDate(
                purchase.purchasedAt.toLocal(),
              ),
            ),
            const SizedBox(height: 6),
            _MetaRow(
              label: 'Importo',
              value: _PurchaseDisplay.amountLabel(purchase),
            ),
            const SizedBox(height: 6),
            _MetaRow(
              label: 'Riferimento ordine',
              value: _PurchaseDisplay.orderReferenceLabel(purchase),
            ),
            const SizedBox(height: 10),
            Text(
              'Ricevuta prossimamente',
              style: textTheme.labelSmall?.copyWith(
                color: _PurchaseCard._textPrimaryColor.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
              ),
            ),
            if (showWatch) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onWatch,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: const Text('Guarda'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF17A1C8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: _MetaRow._textPrimaryColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: _MetaRow._textPrimaryColor.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static const Color _textPrimaryColor = AppVisual.ink;
}
