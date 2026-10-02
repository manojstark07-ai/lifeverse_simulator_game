import '../core/rng.dart';
import 'puzzle.dart';

/// Builds puzzle sets for exams, mock tests, challenges and adaptive practice.
class PuzzleSelector {
  const PuzzleSelector._();

  /// Picks [count] puzzles from [pool], spreading them across categories so
  /// every generated paper exercises different kinds of reasoning.
  static List<Puzzle> stratified(List<Puzzle> pool, int count, Rng rng) {
    final byCategory = <String, List<Puzzle>>{};
    for (final p in pool) {
      byCategory.putIfAbsent(p.category, () => []).add(p);
    }
    final categories = byCategory.keys.toList()..sort();
    rng.shuffle(categories);
    for (final c in categories) {
      byCategory[c]!.sort((a, b) => a.id.compareTo(b.id));
      rng.shuffle(byCategory[c]!);
    }
    final picked = <Puzzle>[];
    var round = 0;
    while (picked.length < count && picked.length < pool.length) {
      for (final c in categories) {
        final list = byCategory[c]!;
        if (round < list.length && picked.length < count) picked.add(list[round]);
      }
      round++;
    }
    // Present easier questions first, like a well-built paper.
    picked.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return picked;
  }

  /// Adaptive practice: aim one difficulty step above the player's comfort
  /// zone when accuracy is high, one below when it is low, and prefer
  /// puzzles that have not been solved yet.
  static Puzzle? adaptive({
    required List<Puzzle> pool,
    required Set<String> solved,
    required int attempts,
    required int correct,
    required Rng rng,
  }) {
    if (pool.isEmpty) return null;
    final accuracy = attempts == 0 ? 0.5 : correct / attempts;
    var target = 1;
    if (attempts >= 3 && accuracy >= 0.75) target = 3;
    if (attempts >= 3 && accuracy >= 0.5 && accuracy < 0.75) target = 2;

    final unsolved = pool.where((p) => !solved.contains(p.id)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final candidates = unsolved.isNotEmpty ? unsolved : ([...pool]..sort((a, b) => a.id.compareTo(b.id)));
    candidates.sort((a, b) {
      final da = (a.difficulty - target).abs();
      final db = (b.difficulty - target).abs();
      return da != db ? da.compareTo(db) : a.id.compareTo(b.id);
    });
    final best = (candidates.first.difficulty - target).abs();
    final top = candidates.where((p) => (p.difficulty - target).abs() == best).toList();
    return top[rng.nextInt(top.length)];
  }
}
