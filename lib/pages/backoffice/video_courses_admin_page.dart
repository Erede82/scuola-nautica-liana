import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/extra_bundle_catalog.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_repositories.dart';
import '../../theme/app_visual_tokens.dart';
import '../../widgets/backoffice/backoffice_formatters.dart';
import '../../widgets/backoffice/backoffice_ui_tokens.dart';

/// Modulo backoffice Videocorsi — prodotti, video e accessi allievo (Fase H1).
class VideoCoursesAdminPage extends StatefulWidget {
  const VideoCoursesAdminPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<VideoCoursesAdminPage> createState() => _VideoCoursesAdminPageState();
}

class _VideoCoursesAdminPageState extends State<VideoCoursesAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();

  List<ExtraProduct>? _products;
  Map<String, int> _videoCounts = {};
  Object? _productsError;
  bool _productsLoading = true;

  List<StudentProfile> _profiles = [];
  Object? _profilesError;
  bool _profilesLoading = true;

  StudentId? _accessStudentId;
  Set<String> _studentPurchasedIds = {};
  bool _accessBusy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() {}));
    _loadProducts();
    _loadProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StudentProfile> get _filteredProfiles {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _profiles;
    return _profiles.where((p) {
      if (p.displayName.toLowerCase().contains(q)) return true;
      if (p.phone != null && p.phone!.toLowerCase().contains(q)) return true;
      if (p.email != null && p.email!.toLowerCase().contains(q)) return true;
      return false;
    }).toList(growable: false);
  }

  StudentProfile? get _selectedAccessProfile {
    final id = _accessStudentId;
    if (id == null) return null;
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _clearAccessStudentSelection() {
    setState(() {
      _accessStudentId = null;
      _studentPurchasedIds = {};
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      _productsLoading = true;
      _productsError = null;
    });
    try {
      final products = await managementRepository.listExtraProducts(
        includeInactive: true,
      );
      final counts = <String, int>{};
      for (final p in products) {
        if (ExtraBundleCatalog.isBundle(p.id)) {
          var total = 0;
          for (final includedId
              in ExtraBundleCatalog.bundleIncludedProductIds) {
            final videos = await managementRepository.listExtraVideoItems(
              includedId,
              includeInactive: true,
            );
            total += videos.where((v) => v.active).length;
          }
          counts[p.id] = total;
        } else {
          final videos = await managementRepository.listExtraVideoItems(
            p.id,
            includeInactive: true,
          );
          counts[p.id] = videos.where((v) => v.active).length;
        }
      }
      if (!mounted) return;
      setState(() {
        _products = products;
        _videoCounts = counts;
        _productsLoading = false;
      });
    } catch (e, st) {
      debugPrint('VideoCoursesAdminPage._loadProducts: $e\n$st');
      if (!mounted) return;
      setState(() {
        _productsError = e;
        _productsLoading = false;
        _products = null;
      });
    }
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _profilesLoading = true;
      _profilesError = null;
    });
    try {
      final list = await backofficeRepository.listStudentProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = list;
        _profilesLoading = false;
      });
    } catch (e, st) {
      debugPrint('VideoCoursesAdminPage._loadProfiles: $e\n$st');
      if (!mounted) return;
      setState(() {
        _profilesError = e;
        _profilesLoading = false;
      });
    }
  }

  Future<void> _loadStudentAccess(StudentId studentId) async {
    setState(() => _accessStudentId = studentId);
    try {
      final ids = await managementRepository.listPurchasedExtraProductIds(
        studentId,
      );
      if (!mounted) return;
      setState(() => _studentPurchasedIds = ids);
    } catch (e, st) {
      debugPrint('VideoCoursesAdminPage._loadStudentAccess: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore caricamento accessi: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openVideoManager(ExtraProduct product) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ProductVideosPage(product: product),
      ),
    );
    await _loadProducts();
  }

  Future<void> _grantAccess(StudentId studentId, String productId) async {
    setState(() => _accessBusy = true);
    try {
      await managementRepository.grantStudentExtraProductAccess(
        studentId: studentId,
        productId: productId,
      );
      if (!mounted) return;
      setState(() {
        _studentPurchasedIds = Set<String>.from(_studentPurchasedIds)
          ..addAll(ExtraBundleCatalog.productsToGrantOnAccess(productId));
        _accessBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ExtraBundleCatalog.isBundle(productId)
                ? ExtraBundleCatalog.grantBundleSnackMessage()
                : 'Accesso videocorso abilitato.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _accessBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Abilitazione fallita: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _revokeAccess(StudentId studentId, String productId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoca accesso'),
        content: const Text(
          'Revocare l\'accesso a questo videocorso per l\'allievo selezionato?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoca'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _accessBusy = true);
    try {
      await managementRepository.revokeStudentExtraProductAccess(
        studentId: studentId,
        productId: productId,
      );
      if (!mounted) return;
      setState(() {
        _studentPurchasedIds = Set<String>.from(_studentPurchasedIds)
          ..removeAll(ExtraBundleCatalog.productsToRevokeOnAccess(productId));
        _accessBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accesso revocato.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _accessBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revoca fallita: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppVisual.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
            Material(
              color: AppVisual.logoBlue,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  'Videocorsi',
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Videocorsi',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BackofficeUiTokens.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestisci prodotti, video e accessi degli allievi.',
                  style: textTheme.bodySmall?.copyWith(
                    color: BackofficeUiTokens.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppVisual.logoBlue,
            unselectedLabelColor: BackofficeUiTokens.textMuted,
            indicatorColor: AppVisual.logoBlue,
            tabs: const [
              Tab(text: 'Prodotti'),
              Tab(text: 'Accessi allievi'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductsTab(textTheme),
                _buildAccessTab(textTheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(TextTheme textTheme) {
    if (_productsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_productsError != null) {
      return _ErrorPanel(
        message: 'Errore caricamento prodotti: $_productsError',
        onRetry: _loadProducts,
      );
    }
    final products = _products ?? const <ExtraProduct>[];
    if (products.isEmpty) {
      return const Center(child: Text('Nessun prodotto videocorso configurato.'));
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final p = products[index];
          final count = _videoCounts[p.id] ?? 0;
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: BackofficeUiTokens.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          p.title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: BackofficeUiTokens.text,
                          ),
                        ),
                      ),
                      _StatusChip(
                        label: p.active ? 'Attivo' : 'Non attivo',
                        color: p.active
                            ? const Color(0xFF2E9E5B)
                            : BackofficeUiTokens.textMuted,
                      ),
                    ],
                  ),
                  if (p.subtitle != null && p.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      p.subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: BackofficeUiTokens.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    ExtraBundleCatalog.uploadGuidance(p.id),
                    style: textTheme.bodySmall?.copyWith(
                      color: ExtraBundleCatalog.isBundle(p.id)
                          ? const Color(0xFF9A6B00)
                          : BackofficeUiTokens.textMuted,
                      height: 1.35,
                      fontWeight: ExtraBundleCatalog.isBundle(p.id)
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        p.priceCents != null
                            ? BackofficeFormatters.moneyEur(p.priceCents!)
                            : 'Prezzo non impostato',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppVisual.logoBlue,
                        ),
                      ),
                      Text(
                        ExtraBundleCatalog.isBundle(p.id)
                            ? '$count video attivi nei corsi inclusi'
                            : '$count video attivi',
                        style: textTheme.bodySmall?.copyWith(
                          color: BackofficeUiTokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _openVideoManager(p),
                      icon: Icon(
                        ExtraBundleCatalog.isBundle(p.id)
                            ? Icons.collections_bookmark_outlined
                            : Icons.video_library_outlined,
                        size: 18,
                      ),
                      label: Text(
                        ExtraBundleCatalog.isBundle(p.id)
                            ? 'Vedi contenuti inclusi'
                            : 'Gestisci video',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessTab(TextTheme textTheme) {
    if (_profilesLoading || _productsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_profilesError != null) {
      return _ErrorPanel(
        message: 'Errore caricamento allievi: $_profilesError',
        onRetry: _loadProfiles,
      );
    }

    final products = _products ?? const <ExtraProduct>[];
    final activeProducts = products.where((p) => p.active).toList();
    final selectedProfile = _selectedAccessProfile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Seleziona un allievo per abilitare o revocare i videocorsi.',
          style: textTheme.bodyMedium?.copyWith(
            color: BackofficeUiTokens.textMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        _VideoCoursesStudentPicker(
          textTheme: textTheme,
          searchCtrl: _searchCtrl,
          profiles: _filteredProfiles,
          selectedProfile: selectedProfile,
          selectedStudentId: _accessStudentId,
          onSelect: _loadStudentAccess,
          onClearSelection: _clearAccessStudentSelection,
        ),
        const SizedBox(height: 20),
        if (_accessStudentId == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Scegli un allievo dall’elenco per gestire gli accessi ai pacchetti video.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppVisual.ink.withValues(alpha: 0.78),
                height: 1.45,
              ),
            ),
          )
        else if (activeProducts.isEmpty)
          const Text('Nessun prodotto attivo disponibile.')
        else ...[
          Text(
            'Pacchetti videocorso',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: BackofficeUiTokens.text,
            ),
          ),
          const SizedBox(height: 8),
          ...activeProducts.map((product) {
            final hasAccess = _studentPurchasedIds.contains(product.id);
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: BackofficeUiTokens.border),
              ),
              child: ListTile(
                title: Text(
                  product.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAccess ? 'Accesso abilitato' : 'Non abilitato',
                      style: TextStyle(
                        color: hasAccess
                            ? const Color(0xFF2E9E5B)
                            : BackofficeUiTokens.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (ExtraBundleCatalog.isBundle(product.id))
                      Text(
                        'Include teoria, carteggio e guida',
                        style: textTheme.labelSmall?.copyWith(
                          color: BackofficeUiTokens.textMuted,
                        ),
                      ),
                  ],
                ),
                trailing: _accessBusy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : hasAccess
                    ? TextButton(
                        onPressed: () => _revokeAccess(
                          _accessStudentId!,
                          product.id,
                        ),
                        child: const Text('Revoca'),
                      )
                    : FilledButton(
                        onPressed: () => _grantAccess(
                          _accessStudentId!,
                          product.id,
                        ),
                        child: const Text('Abilita'),
                      ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _VideoCoursesStudentPicker extends StatelessWidget {
  const _VideoCoursesStudentPicker({
    required this.textTheme,
    required this.searchCtrl,
    required this.profiles,
    required this.selectedProfile,
    required this.selectedStudentId,
    required this.onSelect,
    required this.onClearSelection,
  });

  final TextTheme textTheme;
  final TextEditingController searchCtrl;
  final List<StudentProfile> profiles;
  final StudentProfile? selectedProfile;
  final StudentId? selectedStudentId;
  final ValueChanged<StudentId> onSelect;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    if (selectedProfile != null) {
      return _VideoCoursesStudentCard(
        profile: selectedProfile!,
        textTheme: textTheme,
        selected: true,
        trailing: TextButton(
          onPressed: onClearSelection,
          child: const Text('Cambia allievo'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: 'Cerca allievo per nome, telefono o email',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppVisual.ivory,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppVisual.border.withValues(alpha: 0.72),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppVisual.border.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${profiles.length} allievi',
          style: textTheme.labelMedium?.copyWith(
            color: AppVisual.ink.withValues(alpha: 0.68),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: profiles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nessun allievo corrisponde alla ricerca.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppVisual.ink.withValues(alpha: 0.75),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: profiles.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = profiles[index];
                    return _VideoCoursesStudentCard(
                      profile: p,
                      textTheme: textTheme,
                      selected: p.id == selectedStudentId,
                      onTap: () => onSelect(p.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _VideoCoursesStudentCard extends StatelessWidget {
  const _VideoCoursesStudentCard({
    required this.profile,
    required this.textTheme,
    this.selected = false,
    this.onTap,
    this.trailing,
  });

  final StudentProfile profile;
  final TextTheme textTheme;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first.toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final contactParts = <String>[
      if (profile.phone != null && profile.phone!.trim().isNotEmpty)
        profile.phone!.trim(),
      if (profile.email != null && profile.email!.trim().isNotEmpty)
        profile.email!.trim(),
    ];
    final pathLabel =
        BackofficeFormatters.enrollmentCoursePath(profile.enrolledCoursePath);
    final categoryLabel =
        BackofficeFormatters.categoryName(profile.enrolledLicenseCategory);

    final borderColor = selected
        ? AppVisual.logoBlue.withValues(alpha: 0.55)
        : AppVisual.border.withValues(alpha: 0.72);
    final backgroundColor = selected
        ? AppVisual.logoBlue.withValues(alpha: 0.07)
        : AppVisual.ivory;

    return Material(
      color: backgroundColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppVisual.logoBlue.withValues(alpha: 0.06),
        splashColor: AppVisual.logoBlue.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppVisual.logoBlue.withValues(alpha: 0.12),
                foregroundColor: AppVisual.logoBlue,
                child: Text(
                  _initials(profile.displayName),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppVisual.ink,
                        height: 1.2,
                      ),
                    ),
                    if (contactParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        contactParts.join(' · '),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppVisual.ink.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _InfoChip(label: pathLabel),
                        _InfoChip(label: categoryLabel),
                      ],
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppVisual.logoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppVisual.logoBlue.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppVisual.logoBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ProductVideosPage extends StatefulWidget {
  const _ProductVideosPage({required this.product});

  final ExtraProduct product;

  @override
  State<_ProductVideosPage> createState() => _ProductVideosPageState();
}

class _ProductVideosPageState extends State<_ProductVideosPage> {
  List<ExtraVideoItem> _videos = [];
  List<ExtraVideoItem> _bundleDirectVideos = [];
  List<({String title, String productId, List<ExtraVideoItem> videos})>
  _bundleSections = [];
  bool _loading = true;
  Object? _error;
  bool _moveBusy = false;

  bool get _isBundle => ExtraBundleCatalog.isBundle(widget.product.id);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isBundle) {
        final sections =
            <({String title, String productId, List<ExtraVideoItem> videos})>[];
        for (final sourceId
            in ExtraBundleCatalog.bundleIncludedProductIds) {
          final list = await managementRepository.listExtraVideoItems(
            sourceId,
            includeInactive: true,
          );
          sections.add((
            title: ExtraBundleCatalog.playlistSectionTitle(sourceId),
            productId: sourceId,
            videos: list,
          ));
        }
        final directOnBundle = await managementRepository.listExtraVideoItems(
          widget.product.id,
          includeInactive: true,
        );
        if (!mounted) return;
        setState(() {
          _bundleSections = sections;
          _bundleDirectVideos = directOnBundle;
          _videos = const <ExtraVideoItem>[];
          _loading = false;
        });
        return;
      }

      final list = await managementRepository.listExtraVideoItems(
        widget.product.id,
        includeInactive: true,
      );
      if (!mounted) return;
      setState(() {
        _videos = list;
        _bundleSections = [];
        _bundleDirectVideos = [];
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('_ProductVideosPage._load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({ExtraVideoItem? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ExtraVideoFormDialog(
        product: widget.product,
        existing: existing,
        nextSortOrder: _videos.isEmpty
            ? 0
            : (_videos.map((v) => v.sortOrder).reduce((a, b) => a > b ? a : b) +
                  10),
      ),
    );
    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Video salvato per «${widget.product.title}» (${widget.product.id}).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deactivate(ExtraVideoItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disattiva video'),
        content: Text(
          'Disattivare "${item.title}"? L\'allievo non lo vedrà più nella playlist.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disattiva'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await managementRepository.setExtraVideoItemActive(item.id, false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video disattivato.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Operazione fallita: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _reactivate(ExtraVideoItem item) async {
    try {
      await managementRepository.setExtraVideoItemActive(item.id, true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Riattivazione fallita: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _moveVideo(ExtraVideoItem video, String targetProductId) async {
    setState(() => _moveBusy = true);
    try {
      await managementRepository.moveExtraVideoItemToProduct(
        videoId: video.id,
        targetProductId: targetProductId,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      setState(() => _moveBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '«${video.title}» spostato in '
            '${ExtraBundleCatalog.playlistSectionTitle(targetProductId)} '
            '($targetProductId).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _moveBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Spostamento fallito: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canUpload = ExtraBundleCatalog.allowDirectVideoUpload(widget.product.id);
    final bundleHasIncludedVideos =
        _bundleSections.any((s) => s.videos.isNotEmpty);
    final bundleHasContent =
        bundleHasIncludedVideos || _bundleDirectVideos.isNotEmpty;

    return Scaffold(
        backgroundColor: AppVisual.canvas,
        appBar: AppBar(
          backgroundColor: AppVisual.logoBlue,
          foregroundColor: Colors.white,
          title: Text(widget.product.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (canUpload)
              IconButton(
                tooltip: 'Aggiungi video',
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isBundle
                    ? const Color(0xFFFFF8E8)
                    : AppVisual.logoBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isBundle
                      ? const Color(0xFFE8A317).withValues(alpha: 0.45)
                      : AppVisual.logoBlue.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prodotto: ${widget.product.title} · ID ${widget.product.id}',
                    style: textTheme.labelLarge?.copyWith(
                      color: _isBundle
                          ? const Color(0xFF9A6B00)
                          : AppVisual.logoBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ExtraBundleCatalog.uploadGuidance(widget.product.id),
                    style: textTheme.bodySmall?.copyWith(
                      color: _isBundle
                          ? const Color(0xFF9A6B00)
                          : BackofficeUiTokens.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _ErrorPanel(message: '$_error', onRetry: _load)
                  : _isBundle
                  ? _buildBundleBody(textTheme, bundleHasContent)
                  : _videos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.video_library_outlined, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Nessun video per questo prodotto.',
                              style: textTheme.titleSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _openForm(),
                              icon: const Icon(Icons.add),
                              label: const Text('Aggiungi primo video'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _videos.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _buildEditableVideoTile(textTheme, _videos[index]),
                    ),
            ),
          ],
        ),
      );
  }

  Widget _buildBundleBody(TextTheme textTheme, bool bundleHasContent) {
    if (!bundleHasContent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nessun video nei corsi inclusi. Carica i video in Teoria, Carteggio o Guida.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: BackofficeUiTokens.textMuted,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_bundleDirectVideos.isNotEmpty) ...[
          Text(
            ExtraBundleCatalog.bundleLegacySectionTitle,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF9A6B00),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ExtraBundleCatalog.bundleLegacySectionHint,
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9A6B00),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          ..._bundleDirectVideos.map(
            (v) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildLegacyBundleVideoCard(textTheme, v),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Video nei corsi inclusi',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: BackofficeUiTokens.text,
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final section in _bundleSections) ...[
          if (section.videos.isNotEmpty) ...[
            Text(
              section.title,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: BackofficeUiTokens.text,
              ),
            ),
            Text(
              'Prodotto ${section.productId} — modifica da «Gestisci video» del singolo corso.',
              style: textTheme.labelSmall?.copyWith(
                color: BackofficeUiTokens.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...section.videos.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildReadOnlyVideoTile(textTheme, v),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildLegacyBundleVideoCard(TextTheme textTheme, ExtraVideoItem v) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFE8A317).withValues(alpha: 0.45),
        ),
      ),
      color: const Color(0xFFFFF8E8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  v.active
                      ? Icons.warning_amber_rounded
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF9A6B00),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v.videoUrl ?? '—',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v.active ? 'Attivo' : 'Non attivo',
                        style: textTheme.labelSmall?.copyWith(
                          color: v.active
                              ? const Color(0xFF2E9E5B)
                              : BackofficeUiTokens.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final targetId
                    in ExtraBundleCatalog.bundleIncludedProductIds)
                  OutlinedButton(
                    onPressed: _moveBusy
                        ? null
                        : () => _moveVideo(v, targetId),
                    child: Text(ExtraBundleCatalog.moveTargetLabel(targetId)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyVideoTile(TextTheme textTheme, ExtraVideoItem v) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BackofficeUiTokens.border),
      ),
      child: ListTile(
        leading: Icon(
          v.active ? Icons.play_circle_outline : Icons.visibility_off_outlined,
          color: v.active ? AppVisual.logoBlue : BackofficeUiTokens.textMuted,
        ),
        title: Text(
          v.title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          v.videoUrl ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildEditableVideoTile(TextTheme textTheme, ExtraVideoItem v) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BackofficeUiTokens.border),
      ),
      child: ListTile(
        leading: Icon(
          v.active ? Icons.play_circle_outline : Icons.visibility_off_outlined,
          color: v.active ? AppVisual.logoBlue : BackofficeUiTokens.textMuted,
        ),
        title: Text(
          v.title,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            decoration: v.active ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              v.videoUrl ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
            Text(
              'Ordine ${v.sortOrder}'
              '${v.durationSeconds != null ? ' · ${v.durationSeconds}s' : ''}',
              style: textTheme.labelSmall?.copyWith(
                color: BackofficeUiTokens.textMuted,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            switch (action) {
              case 'edit':
                _openForm(existing: v);
              case 'deactivate':
                _deactivate(v);
              case 'reactivate':
                _reactivate(v);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text('Modifica')),
            if (v.active)
              const PopupMenuItem(value: 'deactivate', child: Text('Disattiva'))
            else
              const PopupMenuItem(value: 'reactivate', child: Text('Riattiva')),
          ],
        ),
      ),
    );
  }
}

class _ExtraVideoFormDialog extends StatefulWidget {
  const _ExtraVideoFormDialog({
    required this.product,
    this.existing,
    required this.nextSortOrder,
  });

  final ExtraProduct product;
  final ExtraVideoItem? existing;
  final int nextSortOrder;

  @override
  State<_ExtraVideoFormDialog> createState() => _ExtraVideoFormDialogState();
}

class _ExtraVideoFormDialogState extends State<_ExtraVideoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _sortCtrl;
  late final TextEditingController _durationCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _urlCtrl = TextEditingController(text: e?.videoUrl ?? '');
    _sortCtrl = TextEditingController(
      text: '${e?.sortOrder ?? widget.nextSortOrder}',
    );
    _durationCtrl = TextEditingController(
      text: e?.durationSeconds?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _sortCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final sort = int.tryParse(_sortCtrl.text.trim()) ?? widget.nextSortOrder;
    final durationRaw = _durationCtrl.text.trim();
    final duration = durationRaw.isEmpty ? null : int.tryParse(durationRaw);

    final input = ExtraVideoItemInput(
      productId: widget.product.id,
      title: _titleCtrl.text.trim(),
      videoUrl: _urlCtrl.text.trim(),
      sortOrder: sort,
      durationSeconds: duration,
      active: widget.existing?.active ?? true,
    );

    try {
      if (widget.existing != null) {
        await managementRepository.updateExtraVideoItem(
          widget.existing!.id,
          input,
        );
      } else {
        await managementRepository.createExtraVideoItem(input);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Salvataggio fallito: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Modifica video' : 'Aggiungi video'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Prodotto: ${widget.product.title} (${widget.product.id})',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppVisual.logoBlue,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Titolo',
                  border: OutlineInputBorder(),
                  helperText: ExtraBundleCatalog.videoTitleNamingHint,
                  helperMaxLines: 4,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL video (pubblico)',
                  border: OutlineInputBorder(),
                  hintText: 'https://…',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obbligatorio';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'URL non valido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Per il player web usa preferibilmente un URL diretto .mp4 con '
                'accesso pubblico/CORS abilitato. I link Google Drive /view '
                'potrebbero non essere riproducibili.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BackofficeUiTokens.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sortCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ordine',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Durata (sec)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvataggio…' : 'Salva'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ),
      ),
    );
  }
}
