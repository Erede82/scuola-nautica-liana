class ModelPrice {
  const ModelPrice({
    required this.inputUsdPerMillion,
    required this.outputUsdPerMillion,
  });

  final double inputUsdPerMillion;
  final double outputUsdPerMillion;
}

class PricingCatalog {
  const PricingCatalog(this.prices);

  final Map<String, ModelPrice> prices;

  double? estimate({
    required String model,
    required int inputTokens,
    required int outputTokens,
  }) {
    final price = prices[model];
    if (price == null) return null;
    return (inputTokens * price.inputUsdPerMillion / 1000000) +
        (outputTokens * price.outputUsdPerMillion / 1000000);
  }
}
