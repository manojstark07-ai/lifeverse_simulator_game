import '../engine/game_state.dart';

/// Cloud-sync contract for Firebase/Firestore or another provider. Keeping
/// conflict resolution here means the gameplay engine never depends on a
/// network connection.
class CloudSaveEnvelope {
  const CloudSaveEnvelope({
    required this.state,
    required this.revision,
    required this.updatedAt,
  });

  final GameState state;
  final int revision;
  final DateTime updatedAt;
}

abstract interface class CloudSyncProvider {
  Future<CloudSaveEnvelope?> pull(String playthroughId);
  Future<CloudSaveEnvelope> push(
    String playthroughId,
    GameState state,
    int revision,
  );
}

class CloudSyncService {
  CloudSyncService(this.provider);

  final CloudSyncProvider provider;

  /// Last-write-wins is only used when the remote revision is newer. Equal
  /// revisions preserve local state, avoiding accidental duplicate uploads.
  Future<CloudSaveEnvelope> reconcile(
    String playthroughId,
    GameState local,
    int localRevision,
  ) async {
    final remote = await provider.pull(playthroughId);
    if (remote != null && remote.revision > localRevision) return remote;
    return provider.push(playthroughId, local, localRevision);
  }
}

class OfflineCloudSyncProvider implements CloudSyncProvider {
  final Map<String, CloudSaveEnvelope> _records = {};

  @override
  Future<CloudSaveEnvelope?> pull(String playthroughId) async =>
      _records[playthroughId];

  @override
  Future<CloudSaveEnvelope> push(
    String playthroughId,
    GameState state,
    int revision,
  ) async {
    final envelope = CloudSaveEnvelope(
      state: state.clone(),
      revision: revision,
      updatedAt: DateTime.now(),
    );
    _records[playthroughId] = envelope;
    return envelope;
  }
}
