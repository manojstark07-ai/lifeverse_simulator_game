import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/settings_repository.dart';

class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._repo, AppSettings initial) : super(initial);

  final SettingsRepository _repo;

  Future<void> update(AppSettings next) async {
    emit(next);
    await _repo.save(next);
  }
}
