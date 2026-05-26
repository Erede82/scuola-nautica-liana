/// Indirizzo di residenza / recapito — mappabile su colonne normalizzate o JSONB in Supabase.
class PostalAddress {
  const PostalAddress({
    this.streetLine1,
    this.streetLine2,
    this.postalCode,
    this.city,
    this.provinceCode,
    this.countryCode,
  });

  final String? streetLine1;
  final String? streetLine2;
  final String? postalCode;
  final String? city;

  /// Sigla provincia (es. MI) o equivalente.
  final String? provinceCode;

  /// ISO 3166-1 alpha-2 consigliato (es. IT).
  final String? countryCode;

  /// Riga unica per elenchi e ricerca testuale.
  String get formattedSingleLine {
    final parts = <String>[
      if (streetLine1 != null && streetLine1!.trim().isNotEmpty) streetLine1!.trim(),
      if (postalCode != null && city != null)
        '${postalCode!.trim()} ${city!.trim()}'
      else if (city != null)
        city!.trim(),
      if (provinceCode != null && provinceCode!.trim().isNotEmpty)
        '(${provinceCode!.trim()})',
      if (countryCode != null && countryCode!.trim().isNotEmpty)
        countryCode!.trim(),
    ];
    return parts.join(', ');
  }
}
