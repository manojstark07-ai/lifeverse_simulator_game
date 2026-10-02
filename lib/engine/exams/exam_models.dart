import '../core/json_utils.dart';

class ExamTier {
  ExamTier({required this.id, required this.label, required this.minComposite});

  factory ExamTier.fromJson(Json j) => ExamTier(
        id: req<String>(j, 'id'),
        label: req<String>(j, 'label'),
        minComposite: reqNum(j, 'minComposite'),
      );

  final String id;
  final String label;
  final double minComposite;
}

/// Data-driven, versioned exam configuration.
///
/// [fictional] exams are invented for the game. Configs modelled on real
/// exams must carry [source] and [verifiedOn] and are only added after the
/// rules have been checked against official notices.
class ExamDefinition {
  ExamDefinition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.version,
    required this.fictional,
    required this.disclaimer,
    required this.description,
    required this.pool,
    required this.questionCount,
    required this.durationSec,
    required this.markCorrect,
    required this.markWrong,
    required this.performanceWeight,
    required this.preparationWeight,
    required this.prepStats,
    required this.prepSkills,
    required this.practicePerSolve,
    required this.practiceCap,
    required this.tiers,
    required this.maxAttempts,
    this.source,
    this.verifiedOn,
  });

  factory ExamDefinition.fromJson(Json j) {
    final marking = (j['marking'] as Map).cast<String, dynamic>();
    final weights = (j['weights'] as Map).cast<String, dynamic>();
    final prep = (j['preparation'] as Map).cast<String, dynamic>();
    return ExamDefinition(
      id: req<String>(j, 'id'),
      name: req<String>(j, 'name'),
      shortName: req<String>(j, 'shortName'),
      version: req<String>(j, 'version'),
      fictional: req<bool>(j, 'fictional'),
      disclaimer: req<String>(j, 'disclaimer'),
      description: req<String>(j, 'description'),
      pool: req<String>(j, 'pool'),
      questionCount: req<num>(j, 'questionCount').toInt(),
      durationSec: req<num>(j, 'durationSec').toInt(),
      markCorrect: reqNum(marking, 'correct'),
      markWrong: reqNum(marking, 'wrong'),
      performanceWeight: reqNum(weights, 'performance'),
      preparationWeight: reqNum(weights, 'preparation'),
      prepStats: numMap(prep['stats']),
      prepSkills: numMap(prep['skills']),
      practicePerSolve: optNum(prep, 'practicePerSolve', 0),
      practiceCap: optNum(prep, 'practiceCap', 0),
      tiers: jsonList(j['tiers']).map(ExamTier.fromJson).toList()
        ..sort((a, b) => b.minComposite.compareTo(a.minComposite)),
      maxAttempts: req<num>(j, 'maxAttempts').toInt(),
      source: j['source'] as String?,
      verifiedOn: j['verifiedOn'] as String?,
    );
  }

  final String id;
  final String name;
  final String shortName;
  final String version;
  final bool fictional;
  final String disclaimer;
  final String description;
  final String pool;
  final int questionCount;
  final int durationSec;
  final double markCorrect;
  final double markWrong;
  final double performanceWeight;
  final double preparationWeight;
  final Map<String, double> prepStats;
  final Map<String, double> prepSkills;
  final double practicePerSolve;
  final double practiceCap;

  /// Sorted from best to worst.
  final List<ExamTier> tiers;
  final int maxAttempts;
  final String? source;
  final String? verifiedOn;

  ExamTier tierFor(double composite) =>
      tiers.firstWhere((t) => composite >= t.minComposite, orElse: () => tiers.last);

  int tierRank(String tierId) => tiers.indexWhere((t) => t.id == tierId);
}

class ExamAttempt {
  ExamAttempt({
    required this.day,
    required this.correct,
    required this.wrong,
    required this.skipped,
    required this.performancePct,
    required this.preparationIndex,
    required this.composite,
    required this.tierId,
  });

  factory ExamAttempt.fromJson(Json j) => ExamAttempt(
        day: j['day'] as int,
        correct: j['correct'] as int,
        wrong: j['wrong'] as int,
        skipped: j['skipped'] as int,
        performancePct: (j['performancePct'] as num).toDouble(),
        preparationIndex: (j['preparationIndex'] as num).toDouble(),
        composite: (j['composite'] as num).toDouble(),
        tierId: j['tierId'] as String,
      );

  final int day;
  final int correct;
  final int wrong;
  final int skipped;
  final double performancePct;
  final double preparationIndex;
  final double composite;
  final String tierId;

  Json toJson() => {
        'day': day,
        'correct': correct,
        'wrong': wrong,
        'skipped': skipped,
        'performancePct': performancePct,
        'preparationIndex': preparationIndex,
        'composite': composite,
        'tierId': tierId,
      };
}

class ExamRecord {
  ExamRecord({required this.examId, List<ExamAttempt>? attempts, this.mockCount = 0, this.bestMockPct = 0})
      : attempts = attempts ?? [];

  factory ExamRecord.fromJson(Json j) => ExamRecord(
        examId: j['examId'] as String,
        attempts: jsonList(j['attempts']).map(ExamAttempt.fromJson).toList(),
        mockCount: optInt(j, 'mockCount', 0),
        bestMockPct: optNum(j, 'bestMockPct', 0),
      );

  final String examId;
  final List<ExamAttempt> attempts;
  int mockCount;
  double bestMockPct;

  ExamAttempt? get latest => attempts.isEmpty ? null : attempts.last;

  Json toJson() => {
        'examId': examId,
        'attempts': attempts.map((a) => a.toJson()).toList(),
        'mockCount': mockCount,
        'bestMockPct': bestMockPct,
      };
}
