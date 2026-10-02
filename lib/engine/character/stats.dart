/// Canonical keys for the five core attributes used by the vertical slice.
///
/// Stats are 0..100 doubles. Intelligence is deliberately *not* modelled as a
/// fixed innate score: [knowledge] is learned and grows with preparation.
class StatKeys {
  const StatKeys._();

  static const knowledge = 'knowledge';
  static const discipline = 'discipline';
  static const communication = 'communication';
  static const wellbeing = 'wellbeing';
  static const energy = 'energy';

  /// Physical health: exercise builds it; smoking, drinking and overwork
  /// erode it. Low health drags energy down and can trigger a health scare.
  static const health = 'health';

  /// Grooming and personal style. Fades without upkeep (salon, gym, clothes).
  static const looks = 'looks';

  /// Public recognition, driven mainly by a creator channel's audience.
  static const fame = 'fame';

  static const all = [knowledge, discipline, communication, wellbeing, energy, health, looks, fame];

  static const labels = {
    knowledge: 'Knowledge',
    discipline: 'Discipline',
    communication: 'Communication',
    wellbeing: 'Well-being',
    energy: 'Energy',
    health: 'Health',
    looks: 'Looks & style',
    fame: 'Fame',
  };
}

/// Professional skills available in the slice. Content may reference only
/// these keys; the content validator enforces it.
class SkillKeys {
  const SkillKeys._();

  static const programming = 'programming';
  static const mathematics = 'mathematics';
  static const accounting = 'accounting';
  static const electrical = 'electrical';
  static const business = 'business';
  static const content = 'content';
  static const styling = 'styling';
  static const cooking = 'cooking';
  static const medicine = 'medicine';
  static const law = 'law';
  static const leadership = 'leadership';

  /// Street smarts: reading people and risk. Crime and gambling build it.
  static const streetwise = 'streetwise';

  static const all = [
    programming, mathematics, accounting, electrical, business, content, styling, cooking,
    medicine, law, leadership, streetwise,
  ];

  static const labels = {
    programming: 'Programming',
    mathematics: 'Mathematics',
    accounting: 'Accounting',
    electrical: 'Electrical work',
    business: 'Business sense',
    content: 'Content creation',
    styling: 'Hair & styling',
    cooking: 'Cooking',
    medicine: 'Medicine & biology',
    law: 'Law & governance',
    leadership: 'Leadership',
    streetwise: 'Street smarts',
  };
}

/// Multiplier keys that personality traits can modify.
class ModifierKeys {
  const ModifierKeys._();

  static const knowledgeGain = 'knowledgeGain';
  static const communicationGain = 'communicationGain';
  static const disciplineGain = 'disciplineGain';
  static const relationshipGain = 'relationshipGain';
  static const wellbeingRecovery = 'wellbeingRecovery';
  static const skillGain = 'skillGain';

  static const all = [
    knowledgeGain,
    communicationGain,
    disciplineGain,
    relationshipGain,
    wellbeingRecovery,
    skillGain,
  ];
}
