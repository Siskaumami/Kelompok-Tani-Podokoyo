import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tani_mobile/core/auth/auth_controller.dart';
import 'package:tani_mobile/core/auth/session.dart';
import 'package:tani_mobile/core/config/app_config.dart';
import 'package:tani_mobile/core/errors/app_error.dart';
import 'package:tani_mobile/core/network/api_client.dart';
import 'package:tani_mobile/core/network/mutation.dart';

import '../support/fakes.dart';

void main() {
  late TestHarness harness;
  setUp(() {
    harness = TestHarness();
  });
  tearDown(() => harness.dispose());
  Future<void> restore() async {
    await harness.container.read(authProvider.notifier).restore();
  }

  test(
    'restores opaque cookie, current user and in-memory CSRF from server',
    () async {
      await restore();
      expect(harness.container.read(authProvider).user!.isOwner, isTrue);
      final request = harness.server.adapter.requests.single;
      expect(request.uri.host, 'api.example.test');
      expect(request.headers['Cookie'], '__Host-tani_session=$fakeToken');
      expect(harness.store.writes, 0);
    },
  );
  test(
    'valid login persists only opaque session, no raw credentials',
    () async {
      await harness.container
          .read(authProvider.notifier)
          .login('OWNER@EXAMPLE.TEST', 'a-test-password');
      expect(harness.container.read(authProvider).authenticated, isTrue);
      expect(harness.store.writes, 1);
      final body = bodyOf(harness.server.adapter.requests.single);
      expect(body['email'], 'owner@example.test');
      expect(
        harness.store.cookie!.encode(),
        isNot(contains('a-test-password')),
      );
    },
  );
  test('invalid login preserves authoritative Indonesian error', () async {
    harness.server.overrides['POST /auth/login'] = (_) => Reply.error(
      401,
      'INVALID_CREDENTIALS',
      'Email atau kata sandi tidak sesuai.',
    );
    await expectLater(
      harness.container
          .read(authProvider.notifier)
          .login('x@example.test', 'wrong'),
      throwsA(
        isA<AppError>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS'),
      ),
    );
    expect(harness.store.writes, 0);
  });
  test('mutations send exact origin, csrf and actor-bound UUID with unchanged body', () async {
    await restore();
    final mutation = PendingMutation(
      path: '/harvests/$recordId/finalize',
      method: 'POST',
      payload: {},
    );
    await harness.api.mutate(mutation);
    final request = harness.server.adapter.requests.last;
    expect(request.headers['Origin'], 'https://app.example.test');
    expect(request.headers['X-CSRF-Token'], fakeCsrf);
    expect(request.headers['Idempotency-Key'], mutation.key);
    expect(bodyOf(request), isEmpty);
  });
  test('uncertain write is never automatically retried; manual replay uses exact bytes and key', () async {
    await restore();
    var calls = 0;
    harness.server.overrides['POST /sales'] = (request) {
      calls++;
      if (calls == 1) {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return const Reply({'id': recordId});
    };
    final mutation = PendingMutation(
      path: '/sales',
      method: 'POST',
      payload: {'notes': 'unchanged'},
    );
    await expectLater(
      harness.api.mutate(mutation),
      throwsA(isA<AppError>().having((e) => e.uncertain, 'uncertain', true)),
    );
    expect(calls, 1);
    await harness.api.mutate(mutation);
    expect(calls, 2);
    final requests = harness.server.adapter.requests
        .where((r) => r.uri.path.endsWith('/sales'))
        .toList();
    expect(requests[0].data, requests[1].data);
    expect(
      requests[0].headers['Idempotency-Key'],
      requests[1].headers['Idempotency-Key'],
    );
  });
  for (final (status, code) in [
    (401, 'AUTH_REQUIRED'),
    (403, 'ACCOUNT_CHANGED'),
    (403, 'CSRF_REJECTED'),
  ]) {
    test(
      '$status $code immediately clears authentication and persisted cookie',
      () async {
        await restore();
        harness.server.overrides['GET /inventory'] = (_) =>
            Reply.error(status, code, 'Masuk kembali.');
        await expectLater(
          harness.api.get('/inventory'),
          throwsA(isA<AppError>()),
        );
        expect(
          harness.container.read(authProvider).status,
          AuthStatus.signedOut,
        );
        expect(harness.store.cookie, isNull);
      },
    );
  }
  test(
    'normal 403 does not silently turn a permission error into logout',
    () async {
      await restore();
      harness.server.overrides['POST /users/invitations'] = (_) =>
          Reply.error(403, 'FORBIDDEN', 'Hanya Owner.');
      await expectLater(
        harness.api.mutate(
          PendingMutation(
            path: '/users/invitations',
            method: 'POST',
            payload: {},
          ),
        ),
        throwsA(isA<AppError>()),
      );
      expect(harness.container.read(authProvider).authenticated, isTrue);
    },
  );
  test(
    'logout calls existing server route before clearing local authentication',
    () async {
      await restore();
      await harness.container.read(authProvider.notifier).logout();
      expect(harness.container.read(authProvider).status, AuthStatus.signedOut);
      expect(harness.store.cookie, isNull);
      expect(
        harness.server.adapter.requests.last.uri.path,
        '/api/v1/auth/logout',
      );
    },
  );
  test('network failure while restoring is explicit and retains secure cookie for read-only retry', () async {
    harness.server.overrides['GET /auth/me'] = (r) => throw DioException(
      requestOptions: r,
      type: DioExceptionType.connectionError,
    );
    await restore();
    expect(harness.container.read(authProvider).status, AuthStatus.unavailable);
    expect(harness.store.cookie, isNotNull);
    harness.server.overrides.clear();
    await restore();
    expect(harness.container.read(authProvider).authenticated, isTrue);
  });
  test('server role changes replace client permissions, including owner transfer effects', () async {
    await restore();
    harness.server.role = 'ADMIN';
    await harness.container.read(authProvider.notifier).verify();
    expect(harness.container.read(authProvider).user!.isOwner, isFalse);
  });
  test('logout failure is shown and never claimed successful', () async {
    await restore();
    harness.server.overrides['POST /auth/logout'] = (r) => throw DioException(
      requestOptions: r,
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      harness.container.read(authProvider.notifier).logout(),
      throwsA(isA<AppError>()),
    );
    expect(harness.container.read(authProvider).authenticated, isTrue);
  });
  test('stale inventory, validation, unavailable database and rate limit remain distinct', () async {
    await restore();
    for (final (status, code) in [
      (409, 'STALE_BASELINE'),
      (422, 'VALIDATION'),
      (503, 'DATABASE_UNAVAILABLE'),
      (429, 'RATE_LIMIT'),
    ]) {
      harness.server.overrides['POST /opnames/$recordId/complete'] = (_) =>
          Reply.error(
            status,
            code,
            'Pesan server',
            details: [
              {'field': 'physical_quantity', 'message': 'Periksa jumlah.'},
            ],
          );
      await expectLater(
        harness.api.mutate(
          PendingMutation(
            path: '/opnames/$recordId/complete',
            method: 'POST',
            payload: {},
          ),
        ),
        throwsA(
          isA<AppError>()
              .having((e) => e.code, 'code', code)
              .having(
                (e) => e.issues.single.field,
                'field',
                'physical_quantity',
              ),
        ),
      );
    }
  });
  test(
    'malformed success is uncertain for a write and explicit for a read',
    () async {
      await restore();
      harness.server.overrides['POST /sales'] = (_) =>
          const Reply({}, envelope: false);
      await expectLater(
        harness.api.mutate(
          PendingMutation(path: '/sales', method: 'POST', payload: {}),
        ),
        throwsA(isA<AppError>().having((e) => e.uncertain, 'uncertain', true)),
      );
      harness.server.overrides['GET /inventory'] = (_) =>
          const Reply({}, envelope: false);
      await expectLater(
        harness.api.get('/inventory'),
        throwsA(isA<AppError>().having((e) => e.uncertain, 'uncertain', false)),
      );
    },
  );
  test('missing/unsafe login cookie cannot create authenticated state', () async {
    harness.server.overrides['POST /auth/login'] = (_) => Reply(
      {'user': userJson(), 'csrf': fakeCsrf},
      headers: {
        'set-cookie': [
          '__Host-tani_session=$fakeToken; Max-Age=43200; Path=/; HttpOnly; Secure; Domain=example.test',
        ],
      },
    );
    await expectLater(
      harness.container
          .read(authProvider.notifier)
          .login('x@example.test', 'password'),
      throwsA(isA<AppError>()),
    );
    expect(harness.store.cookie, isNull);
    expect(harness.container.read(authProvider).authenticated, isFalse);
  });
  test('redirects cannot send session material to another host', () async {
    await restore();
    harness.server.overrides['GET /inventory'] = (_) => const Reply(
      null,
      status: 302,
      headers: {
        'location': ['https://evil.example/inventory'],
      },
    );
    await expectLater(harness.api.get('/inventory'), throwsA(isA<AppError>()));
    expect(
      harness.server.adapter.requests.every(
        (r) => r.uri.host == 'api.example.test',
      ),
      isTrue,
    );
  });
  test(
    'multipart image upload uses the existing image field and stable UUID',
    () async {
      await restore();
      final bytes = Uint8List.fromList([255, 216, 255, 0, 1, 2]);
      final key = uuidV4();
      await harness.api.upload(bytes, 'fixture.jpg', key);
      final request = harness.server.adapter.requests.last;
      expect(request.data, isA<FormData>());
      expect((request.data as FormData).files.single.key, 'image');
      expect(request.headers['Idempotency-Key'], key);
      expect(request.headers['X-CSRF-Token'], fakeCsrf);
    },
  );
  test(
    'image validation rejects executable and oversized uploads before sending',
    () {
      expect(
        () => validateImage(Uint8List.fromList([60, 115, 99, 114])),
        throwsA(isA<AppError>()),
      );
      expect(
        () => validateImage(Uint8List(5 * 1024 * 1024 + 1)),
        throwsA(isA<AppError>()),
      );
    },
  );
  test('explicit debug HTTP can use the development session cookie', () async {
    final adapter = FakeAdapter(
      (_) => Reply(
        {'user': userJson(), 'csrf': fakeCsrf},
        headers: {
          'set-cookie': [
            'tani_session=$fakeToken; Max-Age=43200; Path=/; HttpOnly; SameSite=Lax',
          ],
        },
      ),
    );
    final dio = Dio();
    dio.httpClientAdapter = adapter;
    final store = MemorySessionStore();
    final api = ApiClient(
      AppConfig.parse('http://dev.example.test', release: false),
      store,
      dio: dio,
    );
    await api.authPost('/auth/login', {
      'email': 'owner@example.test',
      'password': 'fixture',
    });
    expect(api.hasSession, isTrue);
    api.close();
  });
  test('null or empty mutation receipts are uncertain instead of claimed successful', () async {
    await restore();
    for (final data in [null, <String, Object?>{}, 'unexpected']) {
      harness.server.overrides['POST /sales'] = (_) => Reply(data);
      await expectLater(
        harness.api.mutate(
          PendingMutation(path: '/sales', method: 'POST', payload: {}),
        ),
        throwsA(
          isA<AppError>().having((error) => error.uncertain, 'uncertain', true),
        ),
      );
    }
  });
}
