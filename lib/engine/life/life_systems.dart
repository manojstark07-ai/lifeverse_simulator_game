import '../core/json_utils.dart';

/// A player-owned venture. The model is intentionally compact so a business
/// can grow from a weekend project into a company without needing a second
/// simulation state.
class BusinessVenture {
  BusinessVenture({
    required this.id,
    required this.name,
    required this.sector,
    required this.cityId,
    required this.foundedDay,
    this.cash = 0,
    this.monthlyRevenue = 0,
    this.monthlyCosts = 0,
    this.valuation = 0,
    this.employees = 0,
    this.productStage = 1,
    this.reputation = 25,
    this.active = true,
    List<String>? projects,
  }) : projects = projects ?? [];

  factory BusinessVenture.fromJson(Json j) => BusinessVenture(
    id: j['id'] as String,
    name: j['name'] as String,
    sector: j['sector'] as String,
    cityId: j['cityId'] as String,
    foundedDay: j['foundedDay'] as int,
    cash: optInt(j, 'cash', 0),
    monthlyRevenue: optInt(j, 'monthlyRevenue', 0),
    monthlyCosts: optInt(j, 'monthlyCosts', 0),
    valuation: optInt(j, 'valuation', 0),
    employees: optInt(j, 'employees', 0),
    productStage: optInt(j, 'productStage', 1),
    reputation: optNum(j, 'reputation', 25),
    active: j['active'] as bool? ?? true,
    projects: stringList(j['projects']),
  );

  final String id;
  final String name;
  final String sector;
  final String cityId;
  final int foundedDay;
  int cash;
  int monthlyRevenue;
  int monthlyCosts;
  int valuation;
  int employees;
  int productStage;
  double reputation;
  bool active;
  List<String> projects;

  int get monthlyProfit => monthlyRevenue - monthlyCosts;

  Json toJson() => {
    'id': id,
    'name': name,
    'sector': sector,
    'cityId': cityId,
    'foundedDay': foundedDay,
    'cash': cash,
    'monthlyRevenue': monthlyRevenue,
    'monthlyCosts': monthlyCosts,
    'valuation': valuation,
    'employees': employees,
    'productStage': productStage,
    'reputation': reputation,
    'active': active,
    'projects': projects,
  };
}

class PropertyAsset {
  PropertyAsset({
    required this.id,
    required this.name,
    required this.kind,
    required this.cityId,
    required this.purchasedDay,
    required this.value,
    this.mortgage = 0,
    this.monthlyMaintenance = 0,
    this.monthlyRent = 0,
    this.occupied = false,
  });

  factory PropertyAsset.fromJson(Json j) => PropertyAsset(
    id: j['id'] as String,
    name: j['name'] as String,
    kind: j['kind'] as String,
    cityId: j['cityId'] as String,
    purchasedDay: j['purchasedDay'] as int,
    value: j['value'] as int,
    mortgage: optInt(j, 'mortgage', 0),
    monthlyMaintenance: optInt(j, 'monthlyMaintenance', 0),
    monthlyRent: optInt(j, 'monthlyRent', 0),
    occupied: j['occupied'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String kind;
  final String cityId;
  final int purchasedDay;
  int value;
  int mortgage;
  int monthlyMaintenance;
  int monthlyRent;
  bool occupied;

  int get equity => value - mortgage;

  Json toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'cityId': cityId,
    'purchasedDay': purchasedDay,
    'value': value,
    'mortgage': mortgage,
    'monthlyMaintenance': monthlyMaintenance,
    'monthlyRent': monthlyRent,
    'occupied': occupied,
  };
}

class InsurancePolicy {
  InsurancePolicy({
    required this.id,
    required this.kind,
    required this.coverage,
    required this.deductible,
    required this.monthlyPremium,
    required this.startedDay,
    this.active = true,
  });

  factory InsurancePolicy.fromJson(Json j) => InsurancePolicy(
    id: j['id'] as String,
    kind: j['kind'] as String,
    coverage: j['coverage'] as int,
    deductible: j['deductible'] as int,
    monthlyPremium: j['monthlyPremium'] as int,
    startedDay: j['startedDay'] as int,
    active: j['active'] as bool? ?? true,
  );

  final String id;
  final String kind;
  final int coverage;
  final int deductible;
  final int monthlyPremium;
  final int startedDay;
  bool active;

  Json toJson() => {
    'id': id,
    'kind': kind,
    'coverage': coverage,
    'deductible': deductible,
    'monthlyPremium': monthlyPremium,
    'startedDay': startedDay,
    'active': active,
  };
}

class LegacyRecord {
  LegacyRecord({
    required this.name,
    required this.day,
    required this.chapter,
    required this.netWorth,
    required this.ending,
  });

  factory LegacyRecord.fromJson(Json j) => LegacyRecord(
    name: j['name'] as String,
    day: j['day'] as int,
    chapter: j['chapter'] as int,
    netWorth: j['netWorth'] as int,
    ending: j['ending'] as String,
  );

  final String name;
  final int day;
  final int chapter;
  final int netWorth;
  final String ending;

  Json toJson() => {
    'name': name,
    'day': day,
    'chapter': chapter,
    'netWorth': netWorth,
    'ending': ending,
  };
}

/// Systems that outlive a single story chapter. Keeping them together lets
/// saves from older versions load with sensible defaults and gives New Life+
/// a clean place to store the previous life.
class LifeSystemsState {
  LifeSystemsState({
    List<BusinessVenture>? businesses,
    List<PropertyAsset>? properties,
    List<InsurancePolicy>? insurance,
    this.retirementBalance = 0,
    this.retirementContributions = 0,
    this.taxesPaid = 0,
    this.taxesDue = 0,
    this.lastTaxYear = 2025,
    this.retired = false,
    this.retirementDay,
    this.deceased = false,
    this.deathDay,
    this.deathReason,
    this.generation = 1,
    Set<String>? visitedCities,
    List<LegacyRecord>? legacy,
    this.nextBusinessSeq = 1,
    this.nextPropertySeq = 1,
  }) : businesses = businesses ?? [],
       properties = properties ?? [],
       insurance = insurance ?? [],
       visitedCities = visitedCities ?? {},
       legacy = legacy ?? [];

  factory LifeSystemsState.fromJson(Json j) => LifeSystemsState(
    businesses: jsonList(
      j['businesses'],
    ).map(BusinessVenture.fromJson).toList(),
    properties: jsonList(j['properties']).map(PropertyAsset.fromJson).toList(),
    insurance: jsonList(j['insurance']).map(InsurancePolicy.fromJson).toList(),
    retirementBalance: optInt(j, 'retirementBalance', 0),
    retirementContributions: optInt(j, 'retirementContributions', 0),
    taxesPaid: optInt(j, 'taxesPaid', 0),
    taxesDue: optInt(j, 'taxesDue', 0),
    lastTaxYear: optInt(j, 'lastTaxYear', 2025),
    retired: j['retired'] as bool? ?? false,
    retirementDay: j['retirementDay'] as int?,
    deceased: j['deceased'] as bool? ?? false,
    deathDay: j['deathDay'] as int?,
    deathReason: j['deathReason'] as String?,
    generation: optInt(j, 'generation', 1),
    visitedCities: stringList(j['visitedCities']).toSet(),
    legacy: jsonList(j['legacy']).map(LegacyRecord.fromJson).toList(),
    nextBusinessSeq: optInt(j, 'nextBusinessSeq', 1),
    nextPropertySeq: optInt(j, 'nextPropertySeq', 1),
  );

  List<BusinessVenture> businesses;
  List<PropertyAsset> properties;
  List<InsurancePolicy> insurance;
  int retirementBalance;
  int retirementContributions;
  int taxesPaid;
  int taxesDue;
  int lastTaxYear;
  bool retired;
  int? retirementDay;
  bool deceased;
  int? deathDay;
  String? deathReason;
  int generation;
  Set<String> visitedCities;
  List<LegacyRecord> legacy;
  int nextBusinessSeq;
  int nextPropertySeq;

  int get totalBusinessValue =>
      businesses.where((b) => b.active).fold(0, (sum, b) => sum + b.valuation);
  int get propertyEquity => properties.fold(0, (sum, p) => sum + p.equity);

  Json toJson() => {
    'businesses': businesses.map((b) => b.toJson()).toList(),
    'properties': properties.map((p) => p.toJson()).toList(),
    'insurance': insurance.map((p) => p.toJson()).toList(),
    'retirementBalance': retirementBalance,
    'retirementContributions': retirementContributions,
    'taxesPaid': taxesPaid,
    'taxesDue': taxesDue,
    'lastTaxYear': lastTaxYear,
    'retired': retired,
    'retirementDay': retirementDay,
    'deceased': deceased,
    'deathDay': deathDay,
    'deathReason': deathReason,
    'generation': generation,
    'visitedCities': visitedCities.toList()..sort(),
    'legacy': legacy.map((x) => x.toJson()).toList(),
    'nextBusinessSeq': nextBusinessSeq,
    'nextPropertySeq': nextPropertySeq,
  };
}
