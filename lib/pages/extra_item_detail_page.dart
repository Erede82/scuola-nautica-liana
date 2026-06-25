import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/extra_bundle_catalog.dart';
import '../domain/backoffice/backoffice.dart';
import '../models/extra_content_item.dart';
import '../repositories/backoffice/management_repository.dart';
import '../repositories/backoffice/management_repository_registry.dart';
import '../services/demo_student_enrollment.dart';
import '../theme/app_visual_tokens.dart';
import 'extra_video_player_page.dart';

/// Dettaglio scheda Extra con checkout verso Stripe (UI preparatoria).
class ExtraItemDetailPage extends StatefulWidget {
  const ExtraItemDetailPage({
    super.key,
    required this.item,
    required this.initiallyPurchased,
  });

  final ExtraContentItem item;
  final bool initiallyPurchased;

  @override
  State<ExtraItemDetailPage> createState() => _ExtraItemDetailPageState();
}

class _ExtraItemDetailPageState extends State<ExtraItemDetailPage>
    with WidgetsBindingObserver {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _brandAqua = Color(0xFF17A1C8);
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  late bool _purchased;
  List<ExtraVideoItem>? _videos;
  List<({String title, List<ExtraVideoItem> videos})>? _bundleSections;
  Object? _videosError;
  bool _videosLoading = false;
  bool _checkoutBusy = false;

  bool get _isBundle => ExtraBundleCatalog.isBundle(widget.item.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _purchased = widget.initiallyPurchased || widget.item.isUnlocked;
    if (_purchased && !widget.item.isComingSoon) {
      _loadVideos();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_purchased) {
      unawaited(_refreshPurchaseState());
    }
  }

  Future<void> _refreshPurchaseState() async {
    final studentId = studentSession.value?.studentId;
    if (studentId == null) return;
    final ids = await managementRepository.listPurchasedExtraProductIds(
      studentId,
    );
    if (!mounted || !ids.contains(widget.item.id)) return;
    setState(() => _purchased = true);
    await _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _videosLoading = true;
      _videosError = null;
    });
    try {
      if (_isBundle) {
        final sections = <({String title, List<ExtraVideoItem> videos})>[];
        for (final sourceId
            in ExtraBundleCatalog.bundleIncludedProductIds) {
          final list = await managementRepository.listExtraVideoItems(sourceId);
          final activeVideos = list.where((v) => v.active).toList();
          if (activeVideos.isNotEmpty) {
            sections.add((
              title: ExtraBundleCatalog.playlistSectionTitle(sourceId),
              videos: activeVideos,
            ));
          }
        }
        if (!mounted) return;
        setState(() {
          _bundleSections = sections;
          _videos = null;
          _videosLoading = false;
        });
        return;
      }

      final list = await managementRepository.listExtraVideoItems(widget.item.id);
      if (!mounted) return;
      if (list.isEmpty) {
        debugPrint(
          'ExtraItemDetailPage: playlist vuota per ${widget.item.id} '
          '(acquisto attivo=$_purchased). Verificare RLS extra_video_items_select_purchased.',
        );
      }
      setState(() {
        _videos = list;
        _bundleSections = null;
        _videosLoading = false;
      });
    } catch (e, st) {
      debugPrint('ExtraItemDetailPage._loadVideos: $e\n$st');
      if (!mounted) return;
      setState(() {
        _videosError = e;
        _videosLoading = false;
        _videos = null;
        _bundleSections = null;
      });
    }
  }

  void _openVideo(ExtraVideoItem video) {
    final url = video.videoUrl?.trim();
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL video non disponibile.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ExtraVideoPlayerPage(
          title: video.title,
          videoUrl: url,
        ),
      ),
    );
  }

  Future<ExtraProductCheckoutOutcome> _startCheckout() async {
    final studentId = studentSession.value?.studentId;
    if (studentId == null) {
      throw StateError('student_session_missing');
    }
    final outcome = await managementRepository.startExtraProductCheckout(
      studentId: studentId,
      productId: widget.item.id,
      amountCents: _priceCents(widget.item.priceLabel),
      paymentReference: 'extra-ui-${DateTime.now().millisecondsSinceEpoch}',
    );
    if (outcome.unlockedImmediately && mounted) {
      setState(() => _purchased = true);
      await _loadVideos();
    }
    return outcome;
  }

  Future<void> _openStripeCheckout(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl.trim());
    if (uri == null || uri.host.isEmpty) {
      throw StateError('checkout_url_invalid');
    }
    final ok = kIsWeb
        ? await launchUrl(uri, webOnlyWindowName: '_self')
        : await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw StateError('checkout_launch_failed');
    }
  }

  Future<void> _handlePurchaseTap(BuildContext context) async {
    if (_checkoutBusy) return;
    setState(() => _checkoutBusy = true);
    try {
      final outcome = await _startCheckout();
      if (!context.mounted) return;
      if (outcome.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome.errorMessage ??
                  'Impossibile avviare il pagamento. Riprova.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (outcome.unlockedImmediately) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acquisto simulato in ambiente demo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (outcome.isStripeRedirect) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Completa il pagamento su Stripe. '
                'L’accesso si attiverà automaticamente.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _openStripeCheckout(outcome.checkoutUrl!);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile avviare il pagamento. Verifica accesso e riprova.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _checkoutBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        title: Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          _DetailHero(item: widget.item),
          const SizedBox(height: 18),
          Text(
            'In sintesi',
            style: textTheme.labelSmall?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.5),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _neutralColor),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.item.description,
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.item.priceLabel != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prezzo',
                  style: textTheme.labelLarge?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.item.priceLabel!,
                  style: textTheme.titleMedium?.copyWith(
                    color: _primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 20),
          _buildCta(context, widget.item.uiState, purchased: _purchased),
          if (_purchased && !widget.item.isComingSoon) ...[
            const SizedBox(height: 24),
            _buildPlaylist(context, textTheme),
          ],
        ],
      ),
    );
  }

  int? _priceCents(String? label) {
    if (label == null) return null;
    final digits = label.replaceAll(RegExp('[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  Widget _buildPlaylist(BuildContext context, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isBundle ? 'Video del corso completo' : 'Video del corso',
          style: textTheme.labelSmall?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.5),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        if (_videosLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_videosError != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _neutralColor),
            ),
            child: Text(
              'Impossibile caricare i video. Riprova più tardi.',
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.8),
              ),
            ),
          )
        else if (_isBundle)
          ..._buildBundlePlaylist(textTheme)
        else if (_videos == null || _videos!.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _neutralColor),
            ),
            child: Text(
              'Nessun video disponibile per questo pacchetto (${widget.item.id}). '
              'Se in backoffice i video sono presenti, contatta la scuola: '
              'potrebbe mancare l\'accesso ai contenuti sul server.',
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          )
        else
          ..._videos!.map((video) => _buildVideoTile(textTheme, video)),
      ],
    );
  }

  List<Widget> _buildBundlePlaylist(TextTheme textTheme) {
    final sections = _bundleSections ?? const [];
    if (sections.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _neutralColor),
          ),
          child: Text(
            ExtraBundleCatalog.emptyBundlePlaylistMessage(),
            style: textTheme.bodyMedium?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ),
      ];
    }

    return [
      for (final section in sections) ...[
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            section.title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _textPrimaryColor,
            ),
          ),
        ),
        ...section.videos.map((video) => _buildVideoTile(textTheme, video)),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _buildVideoTile(TextTheme textTheme, ExtraVideoItem video) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openVideo(video),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _neutralColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: _primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _textPrimaryColor,
                        ),
                      ),
                      if (video.durationSeconds != null)
                        Text(
                          _formatDuration(video.durationSeconds!),
                          style: textTheme.labelSmall?.copyWith(
                            color: _textPrimaryColor.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '$m min${s > 0 ? ' $s s' : ''}';
    return '$s s';
  }

  Widget _buildCta(
    BuildContext context,
    ExtraCatalogUiState state, {
    required bool purchased,
  }) {
    if (purchased && state != ExtraCatalogUiState.comingSoon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2E9E5B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2E9E5B).withValues(alpha: 0.32),
          ),
        ),
        child: Text(
          'Accesso attivo — seleziona un video dalla playlist.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF1F7A45),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    switch (state) {
      case ExtraCatalogUiState.unlocked:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Riproduzione: in attivazione su questo account.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Apri i contenuti'),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      case ExtraCatalogUiState.premiumLocked:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pagamento sicuro tramite Stripe.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _checkoutBusy
                    ? null
                    : () => _handlePurchaseTap(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandAqua,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _checkoutBusy ? 'Reindirizzamento...' : 'Acquista',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );
      case ExtraCatalogUiState.comingSoon:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: _neutralColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Prossimamente'),
          ),
        );
    }
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.item});

  final ExtraContentItem item;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _brandAqua = Color(0xFF17A1C8);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor,
            _primaryColor.withValues(alpha: 0.9),
            _brandAqua.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.32,
                  ),
                ),
                if (item.priceLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.priceLabel!,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
