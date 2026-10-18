import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/repository.dart';
import '../core/storage/session_store.dart';

final configProvider = Provider<AppConfig>((ref) => AppConfig.environment());
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(ref.watch(configProvider).sessionKey),
);
final apiProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    ref.watch(configProvider),
    ref.watch(sessionStoreProvider),
  );
  ref.onDispose(client.close);
  return client;
});
final repositoryProvider = Provider<Repository>(
  (ref) => Repository(ref.watch(apiProvider)),
);

class DataEpoch extends Notifier<int> {
  @override
  int build() => 0;
  void advance() => state++;
}

final dataEpochProvider = NotifierProvider<DataEpoch, int>(DataEpoch.new);
