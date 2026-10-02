import 'dart:collection';

/// Privacy-first analytics seam. It records only anonymous event names in
/// memory until a real provider is configured, and stays disabled by default.
class AnalyticsService {
  AnalyticsService._();

  static final instance = AnalyticsService._();
  final Queue<String> _events = Queue<String>();
  bool enabled = false;

  void track(String name) {
    if (!enabled) return;
    _events.add(name);
    while (_events.length > 100) {
      _events.removeFirst();
    }
  }

  List<String> drain() {
    final out = _events.toList(growable: false);
    _events.clear();
    return out;
  }
}
