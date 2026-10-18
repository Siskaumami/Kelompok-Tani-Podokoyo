import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tani_mobile/app/providers.dart';
import 'package:tani_mobile/core/auth/session.dart';
import 'package:tani_mobile/core/config/app_config.dart';
import 'package:tani_mobile/core/network/api_client.dart';
import 'package:tani_mobile/core/network/json_data.dart';
import 'package:tani_mobile/core/storage/session_store.dart';

const ownerId = '10000000-0000-4000-8000-000000000001';
const adminId = '10000000-0000-4000-8000-000000000002';
const orgId = '10000000-0000-4000-8000-000000000003';
const productId = '10000000-0000-4000-8000-000000000004';
const gradeAId = '10000000-0000-4000-8000-000000000005';
const gradeBId = '10000000-0000-4000-8000-000000000006';
const finishedId = '10000000-0000-4000-8000-000000000007';
const recordId = '10000000-0000-4000-8000-000000000008';
const farmerId = '10000000-0000-4000-8000-000000000009';
final fakeCsrf = List.filled(64, '2').join();
final fakeToken = List.filled(64, '1').join();
const today = '2026-10-17';
final owner = SessionUser(
  id: ownerId,
  organizationId: orgId,
  name: 'Pengelola uji',
  email: 'owner@example.test',
  role: UserRole.owner,
);
final admin = SessionUser(
  id: adminId,
  organizationId: orgId,
  name: 'Admin uji',
  email: 'admin@example.test',
  role: UserRole.admin,
);
Json userJson([String role = 'OWNER']) => {
  'id': role == 'OWNER' ? ownerId : adminId,
  'org_id': orgId,
  'name': role == 'OWNER' ? 'Pengelola uji' : 'Admin uji',
  'email': role == 'OWNER' ? 'owner@example.test' : 'admin@example.test',
  'role': role,
};

class MemorySessionStore implements SessionStore {
  MemorySessionStore({bool authenticated = false}) {
    if (authenticated) {
      cookie = SessionCookie(
        '__Host-tani_session',
        fakeToken,
        DateTime.now().add(const Duration(hours: 12)),
      );
    }
  }
  SessionCookie? cookie;
  int writes = 0;
  int clears = 0;
  @override
  Future<SessionCookie?> read() async => cookie;
  @override
  Future<void> write(SessionCookie value) async {
    cookie = value;
    writes++;
  }

  @override
  Future<void> clear() async {
    cookie = null;
    clears++;
  }
}

class Reply {
  const Reply(
    this.data, {
    this.status = 200,
    this.headers = const {},
    this.envelope = true,
  });
  final Object? data;
  final int status;
  final Map<String, List<String>> headers;
  final bool envelope;
  factory Reply.error(
    int status,
    String code,
    String message, {
    Object? details,
  }) => Reply(
    {
      'error': {'code': code, 'message': message, 'details': ?details},
    },
    status: status,
    envelope: false,
  );
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final FutureOr<Reply> Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(reply.envelope ? {'data': reply.data} : reply.data),
      reply.status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...reply.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class TestServer {
  String role = 'OWNER';
  bool expired = false;
  final overrides = <String, FutureOr<Reply> Function(RequestOptions)>{};
  late final FakeAdapter adapter = FakeAdapter(handle);
  FutureOr<Reply> handle(RequestOptions request) {
    final path = request.uri.path.replaceFirst('/api/v1', '');
    final handler = overrides['${request.method} $path'];
    if (handler != null) return handler(request);
    if (path == '/auth/login') {
      return Reply(
        {'user': userJson(role), 'csrf': fakeCsrf},
        headers: {
          'set-cookie': [
            '__Host-tani_session=$fakeToken; Max-Age=43200; Path=/; HttpOnly; Secure; SameSite=Lax',
          ],
        },
      );
    }
    if (expired) {
      return Reply.error(
        401,
        'AUTH_REQUIRED',
        'Silakan masuk untuk melanjutkan.',
      );
    }
    if (path == '/auth/me') {
      return Reply({'user': userJson(role), 'csrf': fakeCsrf});
    }
    if (path == '/organization') return Reply(organization);
    if (path == '/notifications') return Reply(notification);
    if (path == '/overview') return Reply(overview);
    if (path == '/reports') return Reply(report);
    if (path == '/reports/pdf') {
      return Reply({
        'filename': 'laporan-$today-$today.pdf',
        'content_base64': base64Encode(
          utf8.encode('%PDF-1.4\n%fixture\n%%EOF'),
        ),
      });
    }
    if (path == '/auth/logout') return const Reply({'logged_out': true});
    if (path == '/auth/change-password') {
      return const Reply({
        'message': 'Kata sandi diperbarui. Silakan masuk kembali.',
      });
    }
    if (path == '/auth/accept-invitation') {
      return const Reply({'message': 'Akun Admin aktif. Silakan masuk.'});
    }
    if (path == '/auth/reset-password') {
      return const Reply({
        'message': 'Kata sandi diperbarui. Silakan masuk kembali.',
      });
    }
    if (path == '/auth/forgot-password') {
      return const Reply({
        'queued': true,
        'message': 'Permintaan pemulihan diterima.',
      }, status: 202);
    }
    if (request.method == 'GET') {
      final entries = <String, Object?>{
        '/products': [product],
        '/farmers': [farmer],
        '/inventory': inventory,
        '/users': [userRow, adminRow],
        '/users/invitations': [],
        '/harvests': page([harvest]),
        '/production/plans': page([plan]),
        '/production/batches': page([batch]),
        '/opnames': page([opname]),
        '/sales': page([sale]),
        '/audit': page([audit]),
        '/sales/$recordId': saleDetail,
        '/products/$productId/history': [economics],
        '/inventory/$gradeAId/movements': page([movement]),
      };
      if (entries.containsKey(path)) return Reply(entries[path]);
    }
    if (request.method != 'GET') return const Reply({'id': recordId});
    return Reply.error(404, 'NOT_FOUND', 'Endpoint tidak ditemukan.');
  }
}

Json page(List<Json> items, {int? next}) => {
  'items': items,
  'next_offset': next,
};
Json get organization => {
  'id': orgId,
  'name': 'Kelompok Tani Uji',
  'slug': 'kelompok-uji',
  'timezone': 'Asia/Jakarta',
  'reminder_time': '19:00:00',
  'reminders_enabled': true,
  'reminder_email': false,
  'grade_a_price_rp': '15000',
  'grade_a_hpp_rp': '7000',
  'village_title': 'Cerita kelompok tani',
  'village_body': 'Profil desa untuk pengujian tampilan.',
  'village_image_id': null,
  'publication': 'DRAFT',
};
Json get notification => {
  'business_date': today,
  'timezone': 'Asia/Jakarta',
  'confirmation': null,
  'reminder_due': true,
  'reminder_time': '19:00',
  'push_configured': true,
  'vapid_public_key': null,
  'push_subscribed': false,
};
Json get product => {
  'id': productId,
  'name': 'Keripik Kentang',
  'sku': 'KP-01',
  'description': 'Produk uji',
  'image_id': null,
  'publication': 'PUBLISHED',
  'shopee_url': '',
  'tokopedia_url': '',
  'whatsapp_url': '',
  'material_g': '250',
  'material_rp': '2000',
  'packaging_rp': '1000',
  'production_rp': '1000',
  'other_rp': '0',
  'hpp_rp': '4000',
  'price_rp': '7000',
  'balance': '120',
  'item_id': finishedId,
  'archived': false,
};
List<Json> get inventory => [
  {
    'id': gradeAId,
    'name': 'Kentang Grade A',
    'kind': 'GRADE_A',
    'balance': '1000000',
    'planned_g': '0',
    'revision': '3',
    'archived': null,
  },
  {
    'id': gradeBId,
    'name': 'Kentang Grade B',
    'kind': 'GRADE_B',
    'balance': '500000',
    'planned_g': '100000',
    'revision': '4',
    'archived': null,
  },
  {
    'id': finishedId,
    'name': 'Keripik Kentang',
    'kind': 'FINISHED',
    'balance': '120',
    'planned_g': '0',
    'revision': '2',
    'archived': false,
  },
];
Json get harvest => {
  'id': recordId,
  'business_date': today,
  'farmer_id': farmerId,
  'farmer_name': 'Petani uji',
  'total_g': '1500000',
  'grade_a_g': '1000000',
  'grade_b_g': '400000',
  'reject_g': '50000',
  'remaining_g': '50000',
  'status': 'DRAFT',
  'notes': '',
};
Json get farmer => {
  'id': farmerId,
  'name': 'Petani uji',
  'bio': 'Anggota kelompok tani.',
  'publication': 'PUBLISHED',
  'archived': false,
  'image_id': null,
};
Json get plan => {
  'id': recordId,
  'product_id': productId,
  'product_name': 'Keripik Kentang',
  'business_date': today,
  'planned_g': '100000',
  'status': 'NEEDS_REVIEW',
  'notes': '',
};
Json get batch => {
  'id': recordId,
  'product_id': productId,
  'business_date': today,
  'product_name_snapshot': 'Keripik Kentang',
  'actual_g': '110000',
  'output_units': '400',
  'theoretical_g': '100000',
  'variance_g': '10000',
  'status': 'COMPLETED',
  'notes': '',
};
Json get opname => {
  'id': recordId,
  'item_id': gradeAId,
  'item_name': 'Kentang Grade A',
  'kind': 'GRADE_A',
  'baseline_quantity': '1000000',
  'baseline_revision': '3',
  'physical_quantity': null,
  'difference': null,
  'reason': null,
  'notes': '',
  'status': 'OPEN',
  'created_at': '2026-10-17T01:00:00Z',
};
Json get sale => {
  'id': recordId,
  'business_date': today,
  'channel': 'OFFLINE',
  'external_ref': '',
  'net_rp': '16500',
  'gross_rp': '18500',
  'discount_rp': '1000',
  'fee_rp': '1000',
  'hpp_rp': '10500',
  'status': 'COMPLETED',
  'void_reason': '',
  'notes': '',
};
Json get saleDetail => {
  ...sale,
  'items': [
    {
      'id': recordId,
      'name_snapshot': 'Kentang Grade A',
      'kind': 'GRADE_A',
      'quantity': '1000',
      'unit_price_rp': '11500',
      'unit_hpp_rp': '6500',
      'gross_rp': '11500',
      'hpp_rp': '6500',
    },
    {
      'id': finishedId,
      'name_snapshot': 'Keripik Kentang Lama',
      'kind': 'FINISHED',
      'quantity': '1',
      'unit_price_rp': '7000',
      'unit_hpp_rp': '4000',
      'gross_rp': '7000',
      'hpp_rp': '4000',
    },
  ],
};
Json get economics => {
  ...product,
  'id': recordId,
  'version': 1,
  'created_at': '2026-10-17T01:00:00Z',
  'reason': '',
};
Json get userRow => {...userJson(), 'active': true};
Json get adminRow => {...userJson('ADMIN'), 'active': true};
Json get audit => {
  'id': recordId,
  'action': 'SALE_RECORDED',
  'actor_name': 'Admin uji',
  'created_at': '2026-10-17T01:00:00Z',
  'reason': '',
  'before_data': null,
  'after_data': saleDetail,
};
Json get movement => {
  'id': recordId,
  'movement_type': 'HARVEST_GRADE_A',
  'created_at': '2026-10-17T01:00:00Z',
  'actor_name': 'Admin uji',
  'delta': '1000000',
  'reason': '',
};
Json get overview => {
  'organization_name': 'Kelompok Tani Uji',
  'today': today,
  'counts': {
    'harvest_count': '1',
    'sale_count': '1',
    'plans_needing_review': '1',
  },
  'today_sales': {'sale_count': '1', 'net_rp': '16500'},
  'inventory': inventory,
};
Json get report => {
  'organization': {'name': 'Kelompok Tani Uji', 'timezone': 'Asia/Jakarta'},
  'period': {'from': today, 'to': today},
  'generated_at': '2026-10-17T01:00:00Z',
  'totals': {
    'grade_a_gross_rp': '11500',
    'finished_gross_rp': '7000',
    'gross_rp': '18500',
    'discount_rp': '1000',
    'fee_rp': '1000',
    'net_rp': '16500',
    'hpp_rp': '10500',
    'profit_rp': '6000',
    'sale_count': 1,
    'voided_count': 0,
  },
  'transactions': [sale],
};

class TestHarness {
  TestHarness({bool authenticated = true, String role = 'OWNER'}) {
    server.role = role;
    store = MemorySessionStore(authenticated: authenticated);
    final dio = Dio();
    dio.httpClientAdapter = server.adapter;
    api = ApiClient(
      AppConfig.parse(
        'https://api.example.test',
        origin: 'https://app.example.test',
      ),
      store,
      dio: dio,
    );
    container = ProviderContainer(
      retry: (_, error) => null,
      overrides: [
        configProvider.overrideWithValue(api.config),
        sessionStoreProvider.overrideWithValue(store),
        apiProvider.overrideWithValue(api),
      ],
    );
  }
  final server = TestServer();
  late final MemorySessionStore store;
  late final ApiClient api;
  late final ProviderContainer container;
  void dispose() {
    container.dispose();
    api.close();
  }
}

Json bodyOf(RequestOptions options) => options.data is String
    ? jsonObject(jsonDecode(options.data as String))
    : jsonObject(options.data);
