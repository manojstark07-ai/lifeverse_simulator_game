import '../core/json_utils.dart';

/// Fictional market instruments. Names are deliberately invented so this is
/// a game market, not a recommendation about real securities.
class StockDefinition {
  const StockDefinition({
    required this.id,
    required this.symbol,
    required this.name,
    required this.sector,
    required this.description,
    required this.initialPrice,
    required this.volatility,
    required this.dividendYield,
  });

  final String id;
  final String symbol;
  final String name;
  final String sector;
  final String description;
  final double initialPrice;
  final double volatility;
  final double dividendYield;
}

const fictionalStocks = [
  StockDefinition(
    id: 'nimbus',
    symbol: 'NMB',
    name: 'Nimbus Devices',
    sector: 'Technology',
    description: 'Consumer devices with fast growth and sharp mood swings.',
    initialPrice: 420,
    volatility: 0.08,
    dividendYield: 0.004,
  ),
  StockDefinition(
    id: 'greenarc',
    symbol: 'GAC',
    name: 'GreenArc Power',
    sector: 'Clean energy',
    description: 'Long projects, patient returns, and policy-sensitive months.',
    initialPrice: 185,
    volatility: 0.045,
    dividendYield: 0.012,
  ),
  StockDefinition(
    id: 'harbor',
    symbol: 'HBR',
    name: 'Harbor Foods',
    sector: 'Consumer',
    description: 'A steadier grocery chain with modest dividends.',
    initialPrice: 96,
    volatility: 0.025,
    dividendYield: 0.02,
  ),
  StockDefinition(
    id: 'mediora',
    symbol: 'MDR',
    name: 'Mediora Biotech',
    sector: 'Biotech',
    description: 'Research breakthroughs can soar; trial setbacks can sting.',
    initialPrice: 260,
    volatility: 0.12,
    dividendYield: 0,
  ),
  StockDefinition(
    id: 'railgrid',
    symbol: 'RGT',
    name: 'RailGrid Logistics',
    sector: 'Infrastructure',
    description: 'A slower-moving backbone business tied to the whole city.',
    initialPrice: 145,
    volatility: 0.035,
    dividendYield: 0.009,
  ),
];

StockDefinition stockDefinition(String id) => fictionalStocks.firstWhere(
  (x) => x.id == id,
  orElse: () => throw StateError('Unknown stock $id'),
);

class StockQuote {
  StockQuote({
    required this.stockId,
    required this.price,
    this.previousPrice,
    List<double>? history,
  }) : history = history ?? [price];

  factory StockQuote.fromJson(Json j) => StockQuote(
    stockId: j['stockId'] as String,
    price: (j['price'] as num).toDouble(),
    previousPrice: (j['previousPrice'] as num?)?.toDouble(),
    history: (j['history'] as List? ?? const [])
        .map((x) => (x as num).toDouble())
        .toList(),
  );

  final String stockId;
  double price;
  double? previousPrice;
  List<double> history;

  double get changePct => previousPrice == null || previousPrice == 0
      ? 0
      : (price - previousPrice!) / previousPrice! * 100;

  Json toJson() => {
    'stockId': stockId,
    'price': price,
    'previousPrice': previousPrice,
    'history': history,
  };
}

class StockHolding {
  StockHolding({
    required this.stockId,
    required this.shares,
    required this.averageCost,
  });

  factory StockHolding.fromJson(Json j) => StockHolding(
    stockId: j['stockId'] as String,
    shares: j['shares'] as int,
    averageCost: (j['averageCost'] as num).toDouble(),
  );

  final String stockId;
  int shares;
  double averageCost;

  Json toJson() => {
    'stockId': stockId,
    'shares': shares,
    'averageCost': averageCost,
  };
}
