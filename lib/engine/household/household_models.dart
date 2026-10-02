import '../core/json_utils.dart';

class PartnerStatus {
  const PartnerStatus._();

  static const single = 'single';
  static const dating = 'dating';
  static const engaged = 'engaged';
  static const married = 'married';

  static const all = [single, dating, engaged, married];

  static const labels = {
    single: 'Single',
    dating: 'Dating',
    engaged: 'Engaged',
    married: 'Married',
  };
}

class Child {
  Child({required this.name, required this.birthDay});

  factory Child.fromJson(Json j) => Child(name: j['name'] as String, birthDay: j['birthDay'] as int);

  final String name;
  final int birthDay;

  int ageOn(int day) => (day - birthDay) ~/ 365;

  Json toJson() => {'name': name, 'birthDay': birthDay};
}

/// The player's romantic partner (an NPC), marriage and children.
class HouseholdState {
  HouseholdState({
    this.partnerId,
    this.status = PartnerStatus.single,
    this.sinceDay,
    this.marriedDay,
    this.divorces = 0,
    List<String>? exes,
    List<Child>? children,
  })  : exes = exes ?? [],
        children = children ?? [];

  factory HouseholdState.fromJson(Json j) => HouseholdState(
        partnerId: j['partnerId'] as String?,
        status: j['status'] as String? ?? PartnerStatus.single,
        sinceDay: j['sinceDay'] as int?,
        marriedDay: j['marriedDay'] as int?,
        divorces: optInt(j, 'divorces', 0),
        exes: stringList(j['exes']),
        children: jsonList(j['children']).map(Child.fromJson).toList(),
      );

  String? partnerId;
  String status;

  /// Day the current status began.
  int? sinceDay;
  int? marriedDay;
  int divorces;
  List<String> exes;
  List<Child> children;

  bool get hasPartner => partnerId != null && status != PartnerStatus.single;
  bool get isMarried => status == PartnerStatus.married;

  Json toJson() => {
        'partnerId': partnerId,
        'status': status,
        'sinceDay': sinceDay,
        'marriedDay': marriedDay,
        'divorces': divorces,
        'exes': exes,
        'children': children.map((c) => c.toJson()).toList(),
      };
}
