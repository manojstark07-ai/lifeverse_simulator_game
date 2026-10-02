/// Deterministic, platform-independent pseudo random generator (mulberry32).
///
/// The whole simulation draws randomness from a single [Rng] whose 32-bit
/// [state] is stored in the save file, so a given seed and a given sequence of
/// player decisions always replay identically (required for tests and replays).
class Rng {
  Rng(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  int get state => _state;

  int nextUint32() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ (t + _imul(t ^ (t >>> 7), t | 61))) & 0xFFFFFFFF;
    return (t ^ (t >>> 14)) & 0xFFFFFFFF;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform int in [0, max).
  int nextInt(int max) {
    assert(max > 0);
    return nextUint32() % max;
  }

  bool chance(double p) => nextDouble() < p;

  /// Symmetric noise in [-amplitude, amplitude].
  double noise(double amplitude) => (nextDouble() * 2 - 1) * amplitude;

  void shuffle<T>(List<T> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// Picks an index according to non-negative [weights]. Returns -1 when all
  /// weights are zero.
  int weightedIndex(List<double> weights) {
    final total = weights.fold<double>(0, (a, b) => a + (b < 0 ? 0 : b));
    if (total <= 0) return -1;
    var roll = nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      final w = weights[i] < 0 ? 0 : weights[i];
      if (roll < w) return i;
      roll -= w;
    }
    return weights.length - 1;
  }

  /// 32-bit integer multiply that stays exact on every Dart platform.
  static int _imul(int a, int b) {
    final aHi = (a >>> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    final bHi = (b >>> 16) & 0xFFFF;
    final bLo = b & 0xFFFF;
    return ((aLo * bLo) + ((((aHi * bLo) + (aLo * bHi)) << 16) & 0xFFFFFFFF)) &
        0xFFFFFFFF;
  }
}
