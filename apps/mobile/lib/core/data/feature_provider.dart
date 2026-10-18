import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/registry.dart';
import '../auth/auth_controller.dart';
import '../errors/app_error.dart';
import '../network/json_data.dart';
import 'feature_spec.dart';

final featureProvider = FutureProvider.autoDispose
    .family<FeatureBundle, (String, int)>((ref, query) async {
      ref.watch(dataEpochProvider);
      final auth = ref.watch(authProvider);
      if (!auth.authenticated) {
        throw const AppError(
          'Silakan masuk untuk melanjutkan.',
          status: 401,
          code: 'AUTH_REQUIRED',
        );
      }
      final feature = features[query.$1]!;
      final repo = ref.watch(repositoryProvider);
      final token = CancelToken();
      ref.onDispose(token.cancel);
      final results = await Future.wait<Object>([
        repo.page(
          feature.endpoint,
          paged: feature.paged,
          offset: query.$2,
          cancelToken: token,
        ),
        repo.object('/organization', cancelToken: token),
        repo.object('/notifications', cancelToken: token),
        for (final lookup in feature.lookups)
          repo.list('/$lookup', cancelToken: token),
      ]);
      final page = results[0] as RecordPage;
      for (final row in page.items) {
        row.validate(
          strings: feature.requiredStrings,
          integers: feature.requiredIntegers,
        );
      }
      final notification = results[2] as RecordData;
      return FeatureBundle(
        page: page,
        organization: results[1] as RecordData,
        today: notification.s('business_date'),
        notifications: notification,
        lookups: {
          for (var i = 0; i < feature.lookups.length; i++)
            feature.lookups[i]: results[i + 3] as List<RecordData>,
        },
      );
    });
final objectProvider = FutureProvider.autoDispose.family<RecordData, String>((
  ref,
  path,
) async {
  ref.watch(dataEpochProvider);
  requireAuthenticated(ref);
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return ref.watch(repositoryProvider).object(path, cancelToken: token);
});
