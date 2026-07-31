import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_visual_tokens.dart';

/// Barra orizzontale di sezioni con frecce di navigazione e fade in overflow.
///
/// Le frecce cambiano la sezione attiva (non solo lo scroll). Lo swipe manuale
/// sposta la barra senza cambiare modulo. Su desktop, se tutte le voci
/// rientrano, frecce e fade restano nascosti.
class BackofficeHorizontalSectionBar extends StatefulWidget {
  const BackofficeHorizontalSectionBar({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.selectedIndex,
    this.onNavigateToIndex,
    this.itemLabels,
    this.height = 58,
    this.backgroundColor = AppVisual.ivory,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final int? selectedIndex;

  /// Navigazione reale al modulo/indice richiesto (tap frecce).
  final ValueChanged<int>? onNavigateToIndex;

  /// Etichette usate nei tooltip/semantics delle frecce (stesso ordine degli item).
  final List<String>? itemLabels;

  final double height;
  final Color backgroundColor;

  @override
  State<BackofficeHorizontalSectionBar> createState() =>
      _BackofficeHorizontalSectionBarState();
}

class _BackofficeHorizontalSectionBarState
    extends State<BackofficeHorizontalSectionBar> {
  final ScrollController _controller = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _overflows = false;
  bool _centering = false;
  bool _disposed = false;
  Size? _lastViewportSize;

  final Map<int, BuildContext> _itemContexts = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncScrollState);
    _scheduleCenterSelected(animate: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_lastViewportSize != size) {
      _lastViewportSize = size;
      _scheduleCenterSelected();
    }
  }

  @override
  void didUpdateWidget(covariant BackofficeHorizontalSectionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.itemCount != widget.itemCount) {
      _scheduleCenterSelected();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_syncScrollState);
    _controller.dispose();
    super.dispose();
  }

  void _scheduleCenterSelected({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      _centerSelected(animate: animate);
      _syncScrollState();
    });
  }

  void _syncScrollState() {
    if (_disposed || !_controller.hasClients) return;
    final position = _controller.position;
    final overflows = position.maxScrollExtent > 1.0;
    final left = overflows && position.pixels > 1.0;
    final right = overflows && position.pixels < position.maxScrollExtent - 1.0;
    if (left == _canScrollLeft &&
        right == _canScrollRight &&
        overflows == _overflows) {
      return;
    }
    setState(() {
      _overflows = overflows;
      _canScrollLeft = left;
      _canScrollRight = right;
    });
  }

  /// Centro geometrico della voce selezionata nel viewport, clampato.
  void _centerSelected({bool animate = true}) {
    if (_disposed || _centering) return;
    final index = widget.selectedIndex;
    if (index == null || index < 0 || index >= widget.itemCount) return;
    if (!_controller.hasClients) return;

    final ctx = _itemContexts[index];
    if (ctx == null || !ctx.mounted) return;
    final itemRender = ctx.findRenderObject();
    if (itemRender is! RenderBox || !itemRender.hasSize) return;

    final position = _controller.position;
    final viewportContext = position.context.notificationContext;
    if (viewportContext == null) return;
    final viewportRender = viewportContext.findRenderObject();
    if (viewportRender is! RenderBox || !viewportRender.hasSize) return;

    final itemOffset = itemRender.localToGlobal(
      Offset.zero,
      ancestor: viewportRender,
    );
    final itemCenter = itemOffset.dx + itemRender.size.width / 2;
    final viewportCenter = viewportRender.size.width / 2;
    final target = (position.pixels + (itemCenter - viewportCenter)).clamp(
      0.0,
      position.maxScrollExtent,
    );

    if ((target - position.pixels).abs() < 0.5) return;

    if (!animate) {
      _controller.jumpTo(target);
      return;
    }

    _centering = true;
    _controller
        .animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          _centering = false;
          if (!_disposed && mounted) {
            _syncScrollState();
          }
        });
  }

  void _navigateBy(int delta) {
    final current = widget.selectedIndex;
    if (current == null) return;
    final next = current + delta;
    if (next < 0 || next >= widget.itemCount) return;
    widget.onNavigateToIndex?.call(next);
  }

  String _arrowTooltip({required bool previous}) {
    final selected = widget.selectedIndex;
    if (selected == null) {
      return previous
          ? 'Apri la sezione precedente'
          : 'Apri la sezione successiva';
    }
    final target = previous ? selected - 1 : selected + 1;
    if (target < 0 || target >= widget.itemCount) {
      return previous
          ? 'Apri la sezione precedente'
          : 'Apri la sezione successiva';
    }
    final labels = widget.itemLabels;
    if (labels != null &&
        target < labels.length &&
        labels[target].trim().isNotEmpty) {
      return 'Apri ${labels[target]}';
    }
    return previous
        ? 'Apri la sezione precedente'
        : 'Apri la sezione successiva';
  }

  bool get _canNavigatePrevious {
    final selected = widget.selectedIndex;
    return widget.onNavigateToIndex != null && selected != null && selected > 0;
  }

  bool get _canNavigateNext {
    final selected = widget.selectedIndex;
    return widget.onNavigateToIndex != null &&
        selected != null &&
        selected < widget.itemCount - 1;
  }

  Widget _buildArrow({
    required bool show,
    required bool enabled,
    required IconData icon,
    required String tooltip,
    required Key key,
    required VoidCallback onPressed,
  }) {
    if (!show) return const SizedBox.shrink();
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Icon(icon, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor,
      child: Container(
        height: widget.height,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppVisual.border)),
        ),
        child: Row(
          children: [
            _buildArrow(
              show: _overflows,
              enabled: _canNavigatePrevious,
              icon: Icons.chevron_left_rounded,
              tooltip: _arrowTooltip(previous: true),
              key: const ValueKey('backoffice-section-scroll-left'),
              onPressed: () => _navigateBy(-1),
            ),
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      _syncScrollState();
                      return false;
                    },
                    child: ListView.separated(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      itemCount: widget.itemCount,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Builder(
                          builder: (itemContext) {
                            _itemContexts[index] = itemContext;
                            return widget.itemBuilder(context, index) ??
                                const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                  ),
                  if (_overflows && _canScrollLeft)
                    const Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: _EdgeFade(left: true),
                    ),
                  if (_overflows && _canScrollRight)
                    const Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: _EdgeFade(left: false),
                    ),
                ],
              ),
            ),
            _buildArrow(
              show: _overflows,
              enabled: _canNavigateNext,
              icon: Icons.chevron_right_rounded,
              tooltip: _arrowTooltip(previous: false),
              key: const ValueKey('backoffice-section-scroll-right'),
              onPressed: () => _navigateBy(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 18,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [AppVisual.ivory, AppVisual.ivory.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Helper per stime di larghezza contenuto (solo test / debug).
@visibleForTesting
double backofficeSectionBarEstimatedContentWidth({
  required int itemCount,
  required double averageItemWidth,
  double separator = 8,
  double padding = 16,
}) {
  if (itemCount <= 0) return 0;
  return padding +
      itemCount * averageItemWidth +
      math.max(0, itemCount - 1) * separator;
}
