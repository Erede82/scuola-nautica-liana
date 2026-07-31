import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_visual_tokens.dart';

/// Barra orizzontale di sezioni con frecce e fade quando il contenuto overflowa.
///
/// Su desktop, se tutte le voci rientrano, frecce e fade restano nascosti.
class BackofficeHorizontalSectionBar extends StatefulWidget {
  const BackofficeHorizontalSectionBar({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.selectedIndex,
    this.height = 58,
    this.backgroundColor = AppVisual.ivory,
    this.scrollStep = 180,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final int? selectedIndex;
  final double height;
  final Color backgroundColor;
  final double scrollStep;

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

  final Map<int, BuildContext> _itemContexts = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncScrollState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScrollState();
      _ensureSelectedVisible();
    });
  }

  @override
  void didUpdateWidget(covariant BackofficeHorizontalSectionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncScrollState();
        _ensureSelectedVisible();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncScrollState);
    _controller.dispose();
    super.dispose();
  }

  void _syncScrollState() {
    if (!_controller.hasClients) return;
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

  Future<void> _scrollBy(double delta) async {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    await _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _syncScrollState();
  }

  void _ensureSelectedVisible() {
    final index = widget.selectedIndex;
    if (index == null || index < 0 || index >= widget.itemCount) return;
    final ctx = _itemContexts[index];
    if (ctx == null || !ctx.mounted) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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
              enabled: _canScrollLeft,
              icon: Icons.chevron_left_rounded,
              tooltip: 'Scorri sezioni a sinistra',
              key: const ValueKey('backoffice-section-scroll-left'),
              onPressed: () => _scrollBy(-widget.scrollStep),
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
              enabled: _canScrollRight,
              icon: Icons.chevron_right_rounded,
              tooltip: 'Scorri sezioni a destra',
              key: const ValueKey('backoffice-section-scroll-right'),
              onPressed: () => _scrollBy(widget.scrollStep),
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
