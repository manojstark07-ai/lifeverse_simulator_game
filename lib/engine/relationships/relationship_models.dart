import '../core/json_utils.dart';

/// A persistent, authored character.
class Npc {
  Npc({
    required this.id,
    required this.name,
    required this.role,
    required this.bio,
    required this.personality,
    required this.interests,
    required this.colorIndex,
    required this.isFamily,
    required this.startAffinity,
    required this.startTrust,
    required this.routineBond,
  });

  factory Npc.fromJson(Json j) => Npc(
        id: req<String>(j, 'id'),
        name: req<String>(j, 'name'),
        role: req<String>(j, 'role'),
        bio: req<String>(j, 'bio'),
        personality: stringList(j['personality']),
        interests: stringList(j['interests']),
        colorIndex: optInt(j, 'colorIndex', 0),
        isFamily: j['isFamily'] as bool? ?? false,
        startAffinity: optNum(j, 'startAffinity', 20),
        startTrust: optNum(j, 'startTrust', 30),
        routineBond: j['routineBond'] as String? ?? 'none',
      );

  final String id;
  final String name;
  final String role;
  final String bio;
  final List<String> personality;
  final List<String> interests;
  final int colorIndex;
  final bool isFamily;
  final double startAffinity;
  final double startTrust;

  /// Which weekly routine bucket keeps this bond warm: `family`, `social`
  /// or `none` (only direct interactions count).
  final String routineBond;
}

/// Something an NPC remembers. Story conditions can query memories by tag,
/// so meaningful moments keep mattering chapters later.
class Memory {
  Memory({required this.day, required this.tag, required this.text, this.weight = 1});

  factory Memory.fromJson(Json j) => Memory(
        day: j['day'] as int,
        tag: j['tag'] as String,
        text: j['text'] as String,
        weight: optNum(j, 'weight', 1),
      );

  final int day;
  final String tag;
  final String text;

  /// Positive memories > 0, painful ones < 0.
  final double weight;

  Json toJson() => {'day': day, 'tag': tag, 'text': text, 'weight': weight};
}

class RelationshipState {
  RelationshipState({
    required this.npcId,
    required this.affinity,
    required this.trust,
    this.conflict = 0,
    this.lastInteractionDay = 0,
    this.met = false,
    List<Memory>? memories,
  }) : memories = memories ?? [];

  factory RelationshipState.fromJson(Json j) => RelationshipState(
        npcId: j['npcId'] as String,
        affinity: (j['affinity'] as num).toDouble(),
        trust: (j['trust'] as num).toDouble(),
        conflict: optNum(j, 'conflict', 0),
        lastInteractionDay: optInt(j, 'lastInteractionDay', 0),
        met: j['met'] as bool? ?? false,
        memories: jsonList(j['memories']).map(Memory.fromJson).toList(),
      );

  final String npcId;

  /// -100..100 warmth.
  double affinity;

  /// 0..100 reliability as perceived by the NPC.
  double trust;

  /// 0..100 unresolved tension.
  double conflict;
  int lastInteractionDay;
  bool met;
  List<Memory> memories;

  bool remembers(String tag) => memories.any((m) => m.tag == tag);

  Json toJson() => {
        'npcId': npcId,
        'affinity': affinity,
        'trust': trust,
        'conflict': conflict,
        'lastInteractionDay': lastInteractionDay,
        'met': met,
        'memories': memories.map((m) => m.toJson()).toList(),
      };
}
