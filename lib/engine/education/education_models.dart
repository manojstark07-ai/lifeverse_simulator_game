import '../core/json_utils.dart';

class InstitutionTier {
  InstitutionTier({
    required this.id,
    required this.name,
    required this.feesPerYear,
    required this.reputation,
  });

  factory InstitutionTier.fromJson(Json j) => InstitutionTier(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        feesPerYear: req<num>(j, 'feesPerYear').toInt(),
        reputation: reqNum(j, 'reputation'),
      );

  final String id;
  final String name;
  final int feesPerYear;

  /// 0..1, feeds interview scoring and starting salaries.
  final double reputation;
}

/// A higher-education or vocational pathway.
class EducationProgram {
  EducationProgram({
    required this.id,
    required this.name,
    required this.shortName,
    required this.field,
    required this.description,
    required this.durationMonths,
    required this.weeklyHours,
    required this.admissionType,
    required this.admissionExamId,
    required this.tiers,
    required this.knowledgeGainPerMonth,
    required this.skillGainsPerMonth,
    required this.gradeSkill,
    required this.careerIds,
    required this.practicePool,
  });

  factory EducationProgram.fromJson(Json j) {
    final admission = (j['admission'] as Map).cast<String, dynamic>();
    return EducationProgram(
      id: req<String>(j, 'id'),
      name: req<String>(j, 'name'),
      shortName: req<String>(j, 'shortName'),
      field: req<String>(j, 'field'),
      description: req<String>(j, 'description'),
      durationMonths: req<num>(j, 'durationMonths').toInt(),
      weeklyHours: reqNum(j, 'weeklyHours'),
      admissionType: req<String>(admission, 'type', 'admission'),
      admissionExamId: admission['examId'] as String?,
      tiers: jsonList(j['tiers']).map(InstitutionTier.fromJson).toList(),
      knowledgeGainPerMonth: reqNum(j, 'knowledgeGainPerMonth'),
      skillGainsPerMonth: numMap(j['skillGainsPerMonth']),
      gradeSkill: req<String>(j, 'gradeSkill'),
      careerIds: stringList(j['careerIds']),
      practicePool: j['practicePool'] as String?,
    );
  }

  final String id;
  final String name;
  final String shortName;
  final String field;
  final String description;
  final int durationMonths;
  final double weeklyHours;

  /// `exam` (tier decided by an entrance exam) or `open` (merit/open intake).
  final String admissionType;
  final String? admissionExamId;
  final List<InstitutionTier> tiers;
  final double knowledgeGainPerMonth;
  final Map<String, double> skillGainsPerMonth;

  /// Skill that most influences semester grades.
  final String gradeSkill;
  final List<String> careerIds;

  /// Puzzle pool for course practice in the Exam Centre.
  final String? practicePool;

  InstitutionTier? tier(String id) {
    for (final t in tiers) {
      if (t.id == id) return t;
    }
    return null;
  }

  int get semesters => (durationMonths / 6).ceil();
}

class EducationStatus {
  const EducationStatus._();
  static const none = 'none';
  static const enrolled = 'enrolled';
  static const graduated = 'graduated';
  static const dropped = 'dropped';
}

class EducationState {
  EducationState({
    this.programId,
    this.tierId,
    this.status = EducationStatus.none,
    this.startDay = 0,
    this.monthsCompleted = 0,
    List<double>? semesterGpas,
    this.backlogs = 0,
    this.scholarshipShare = 0,
    this.scholarshipName,
    List<String>? completedPrograms,
    this.feesPaidSemesters = 0,
  })  : semesterGpas = semesterGpas ?? [],
        completedPrograms = completedPrograms ?? [];

  factory EducationState.fromJson(Json j) => EducationState(
        programId: j['programId'] as String?,
        tierId: j['tierId'] as String?,
        status: j['status'] as String? ?? EducationStatus.none,
        startDay: optInt(j, 'startDay', 0),
        monthsCompleted: optInt(j, 'monthsCompleted', 0),
        semesterGpas: (j['semesterGpas'] as List? ?? [])
            .map((e) => (e as num).toDouble())
            .toList(),
        backlogs: optInt(j, 'backlogs', 0),
        scholarshipShare: optNum(j, 'scholarshipShare', 0),
        scholarshipName: j['scholarshipName'] as String?,
        completedPrograms: stringList(j['completedPrograms']),
        feesPaidSemesters: optInt(j, 'feesPaidSemesters', 0),
      );

  String? programId;
  String? tierId;
  String status;
  int startDay;
  int monthsCompleted;
  List<double> semesterGpas;

  /// Failed semesters that must be cleared before graduating.
  int backlogs;

  /// Fraction of fees covered by a scholarship (0..1).
  double scholarshipShare;
  String? scholarshipName;
  List<String> completedPrograms;
  int feesPaidSemesters;

  bool get isEnrolled => status == EducationStatus.enrolled;

  double get cgpa => semesterGpas.isEmpty
      ? 0
      : semesterGpas.reduce((a, b) => a + b) / semesterGpas.length;

  Json toJson() => {
        'programId': programId,
        'tierId': tierId,
        'status': status,
        'startDay': startDay,
        'monthsCompleted': monthsCompleted,
        'semesterGpas': semesterGpas,
        'backlogs': backlogs,
        'scholarshipShare': scholarshipShare,
        'scholarshipName': scholarshipName,
        'completedPrograms': completedPrograms,
        'feesPaidSemesters': feesPaidSemesters,
      };
}
