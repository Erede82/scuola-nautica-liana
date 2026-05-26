import 'package:flutter/material.dart';

import '../models/license_models.dart';
import 'app_empty_state.dart';

class CategoryContentState extends StatelessWidget {
  const CategoryContentState({
    super.key,
    required this.category,
    required this.availableTitle,
    required this.availableMessage,
    this.availableIcon = Icons.check_circle_outline_rounded,
    this.unavailableTitle,
    this.unavailableMessage,
    this.unavailableIcon = Icons.lock_outline_rounded,
  });

  final LicenseCategory category;
  final String availableTitle;
  final String availableMessage;
  final IconData availableIcon;
  final String? unavailableTitle;
  final String? unavailableMessage;
  final IconData unavailableIcon;

  @override
  Widget build(BuildContext context) {
    final isAvailable = category.isAvailable;
    final title = isAvailable
        ? availableTitle
        : (unavailableTitle ??
            (category.id == LicenseCategoryId.vela
                ? 'Contenuti vela in preparazione'
                : '${category.name} — Disponibile prossimamente'));
    final message = isAvailable
        ? availableMessage
        : (unavailableMessage ??
            (category.id == LicenseCategoryId.vela
                ? 'Stiamo preparando lezioni, schede e quiz per la patente a vela. '
                    'Torna a trovarci: ti avviseremo appena sarà operativo.'
                : 'I contenuti per questa categoria saranno disponibili a breve.'));
    final icon = isAvailable ? availableIcon : unavailableIcon;

    return AppEmptyState(
      title: title,
      message: message,
      icon: icon,
      tagLabel: isAvailable ? null : 'Disponibile prossimamente',
    );
  }
}
