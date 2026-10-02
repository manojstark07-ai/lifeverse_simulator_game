import '../conditions/condition.dart';
import '../core/json_utils.dart';

class CareerLevel {
  CareerLevel({
    required this.title,
    required this.monthlySalary,
    required this.minMonths,
    required this.skillRequired,
  });

  factory CareerLevel.fromJson(Json j) => CareerLevel(
        title: req<String>(j, 'title'),
        monthlySalary: req<num>(j, 'monthlySalary').toInt(),
        minMonths: req<num>(j, 'minMonths').toInt(),
        skillRequired: reqNum(j, 'skillRequired'),
      );

  final String title;
  final int monthlySalary;

  /// Minimum months in the previous level before this one is reachable.
  final int minMonths;
  final double skillRequired;
}

/// A full-time profession with a progression ladder.
class Career {
  Career({
    required this.id,
    required this.name,
    required this.sector,
    required this.description,
    required this.requiredPrograms,
    required this.primarySkill,
    required this.minPrimarySkill,
    required this.interviewPool,
    required this.weeklyHours,
    required this.demand,
    required this.skillGainsPerMonth,
    required this.ladder,
    required this.listed,
    required this.requires,
    required this.requirementNote,
    required this.employers,
  });

  factory Career.fromJson(Json j) => Career(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        sector: req<String>(j, 'sector'),
        description: req<String>(j, 'description'),
        requiredPrograms: stringList(j['requiredPrograms']),
        primarySkill: req<String>(j, 'primarySkill'),
        minPrimarySkill: reqNum(j, 'minPrimarySkill'),
        interviewPool: req<String>(j, 'interviewPool'),
        weeklyHours: reqNum(j, 'weeklyHours'),
        demand: reqNum(j, 'demand'),
        skillGainsPerMonth: numMap(j['skillGainsPerMonth']),
        ladder: jsonList(j['ladder']).map(CareerLevel.fromJson).toList(),
        listed: j['listed'] as bool? ?? true,
        requires: j['requires'] == null ? Condition.always : Condition.fromJson((j['requires'] as Map).cast()),
        requirementNote: j['requirementNote'] as String?,
        employers: stringList(j['employers']),
      );

  final String id;
  final String name;
  final String sector;
  final String description;

  /// Any one of these completed programs qualifies the player.
  final List<String> requiredPrograms;
  final String primarySkill;
  final double minPrimarySkill;
  final String interviewPool;
  final double weeklyHours;

  /// 0..1 job-market demand; scales interview leniency and hiring odds.
  final double demand;
  final Map<String, double> skillGainsPerMonth;
  final List<CareerLevel> ladder;

  /// Whether the career portal lists it (story-only careers are unlisted).
  final bool listed;

  /// Extra eligibility beyond qualifications (a driving licence, a vehicle).
  final Condition requires;

  /// Player-facing summary of [requires].
  final String? requirementNote;

  /// Fictional employers hiring through the job portal.
  final List<String> employers;

  /// Careers with no listed programs are open to anyone who meets [requires]
  /// and the minimum skill.
  bool get needsQualification => requiredPrograms.isNotEmpty;
}

class PartTimeJob {
  PartTimeJob({
    required this.id,
    required this.name,
    required this.employer,
    required this.description,
    required this.weeklyHours,
    required this.monthlyPay,
    required this.skillGainsPerMonth,
    required this.statGainsPerMonth,
  });

  factory PartTimeJob.fromJson(Json j) => PartTimeJob(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        employer: req<String>(j, 'employer'),
        description: req<String>(j, 'description'),
        weeklyHours: reqNum(j, 'weeklyHours'),
        monthlyPay: req<num>(j, 'monthlyPay').toInt(),
        skillGainsPerMonth: numMap(j['skillGainsPerMonth']),
        statGainsPerMonth: numMap(j['statGainsPerMonth']),
      );

  final String id;
  final String name;
  final String employer;
  final String description;
  final double weeklyHours;

  /// Pay before the hometown wage multiplier.
  final int monthlyPay;
  final Map<String, double> skillGainsPerMonth;
  final Map<String, double> statGainsPerMonth;
}

class CareerState {
  CareerState({
    this.partTimeJobId,
    this.careerId,
    this.level = 0,
    this.monthsInRole = 0,
    this.monthsInCareer = 0,
    this.performance = 50,
    this.monthlySalary = 0,
    this.employer,
    List<String>? history,
  }) : history = history ?? [];

  factory CareerState.fromJson(Json j) => CareerState(
        partTimeJobId: j['partTimeJobId'] as String?,
        careerId: j['careerId'] as String?,
        level: optInt(j, 'level', 0),
        monthsInRole: optInt(j, 'monthsInRole', 0),
        monthsInCareer: optInt(j, 'monthsInCareer', 0),
        performance: optNum(j, 'performance', 50),
        monthlySalary: optInt(j, 'monthlySalary', 0),
        employer: j['employer'] as String?,
        history: stringList(j['history']),
      );

  String? partTimeJobId;
  String? careerId;
  int level;
  int monthsInRole;
  int monthsInCareer;

  /// 0..100 rolling job performance.
  double performance;
  int monthlySalary;
  String? employer;
  List<String> history;

  bool get hasCareer => careerId != null;

  Json toJson() => {
        'partTimeJobId': partTimeJobId,
        'careerId': careerId,
        'level': level,
        'monthsInRole': monthsInRole,
        'monthsInCareer': monthsInCareer,
        'performance': performance,
        'monthlySalary': monthlySalary,
        'employer': employer,
        'history': history,
      };
}
