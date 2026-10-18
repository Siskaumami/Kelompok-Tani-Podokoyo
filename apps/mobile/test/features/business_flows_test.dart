import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tani_mobile/app/navigation.dart';
import 'package:tani_mobile/core/auth/auth_controller.dart';
import 'package:tani_mobile/core/data/feature_provider.dart';
import 'package:tani_mobile/core/data/feature_spec.dart';
import 'package:tani_mobile/core/errors/app_error.dart';
import 'package:tani_mobile/core/network/json_data.dart';
import 'package:tani_mobile/core/widgets/forms/form_spec.dart';
import 'package:tani_mobile/features/harvests/data/harvest_feature.dart';
import 'package:tani_mobile/features/products/data/product_feature.dart';
import 'package:tani_mobile/features/production/data/production_feature.dart';
import 'package:tani_mobile/features/production_plans/data/plan_feature.dart';
import 'package:tani_mobile/features/registry.dart';
import 'package:tani_mobile/features/sales/data/sales_feature.dart';
import 'package:tani_mobile/features/sales/data/sale_draft.dart';
import 'package:tani_mobile/features/stock_opname/data/opname_feature.dart';
import 'package:tani_mobile/features/users/data/user_feature.dart';

import '../support/fakes.dart';

FeatureBundle fixtureBundle({List<RecordData>? items}) => FeatureBundle(
  page: RecordPage(items ?? [], null),
  organization: RecordData(organization),
  today: today,
  lookups: {
    'products': [RecordData(product)],
    'farmers': [RecordData(farmer)],
    'inventory': inventory.map(RecordData.new).toList(),
  },
  notifications: RecordData(notification),
);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  final data = fixtureBundle();
  group('Harvest and server-authoritative stock', () {
    test(
      'partial harvest has exact kg conversion and optional zero grades',
      () {
        final form = harvestForm(data);
        final values = form.initialValues()
          ..addAll({
            'total_g': '15,125',
            'grade_a_g': '10',
            'grade_b_g': '4',
            'reject_g': '',
          });
        final result = form.payload(values);
        expect(result, {
          'business_date': today,
          'farmer_id': null,
          'total_g': '15125',
          'grade_a_g': '10000',
          'grade_b_g': '4000',
          'reject_g': '0',
          'notes': '',
        });
      },
    );
    test('sorting exceeding total is rejected before submit', () {
      final form = harvestForm(data);
      expect(
        () => form.payload(
          form.initialValues()..addAll({'total_g': '10', 'grade_a_g': '11'}),
        ),
        throwsFormatException,
      );
    });
    test('harvest finalization, void and finalized edit restrictions match server transitions', () {
      final feature = features['harvests']!;
      expect(
        feature.actions(RecordData(harvest), data, owner).map((a) => a.label),
        ['Edit', 'Selesaikan'],
      );
      expect(
        feature
            .actions(
              RecordData({...harvest, 'status': 'FINALIZED'}),
              data,
              owner,
            )
            .map((a) => a.label),
        ['Batalkan'],
      );
      expect(
        feature.actions(
          RecordData({...harvest, 'status': 'VOIDED'}),
          data,
          owner,
        ),
        isEmpty,
      );
    });
    test('inventory exposes Grade A, Grade B planning and finished units without write endpoints', () {
      final feature = features['inventory']!;
      final cells = feature.cells(RecordData(inventory[1]));
      expect(cells[1].primary, '500 kg');
      expect(cells[2].primary, '100 kg');
      expect(cells[2].secondary.single, 'Belum direncanakan 400 kg');
      expect(feature.create, isNull);
      expect(
        feature
            .actions(RecordData(inventory[0]), data, admin)
            .single
            .detail!
            .type,
        'ledger',
      );
    });
  });
  group('Products and economics', () {
    test('product creation includes complete nested economics and approved WhatsApp conversion', () {
      final form = productForm(data);
      final values = form.initialValues()
        ..addAll({
          'name': 'Keripik',
          'sku': 'K-1',
          'economics.material_g': '250',
          'economics.price_rp': '7000',
          'whatsapp_url': '08123456789',
        });
      final payload = form.payload(values);
      expect(payload['whatsapp_url'], 'https://wa.me/628123456789');
      expect(payload['economics'], {
        'material_g': '250',
        'price_rp': '7000',
        'material_rp': '0',
        'packaging_rp': '0',
        'production_rp': '0',
        'other_rp': '0',
      });
      expect(payload.containsKey('hpp_rp'), isFalse);
    });
    test('metadata update never rewrites economics or archive state', () {
      final form = productForm(data, RecordData(product));
      final payload = form.payload(form.initialValues());
      expect(
        payload.keys,
        unorderedEquals([
          'name',
          'sku',
          'description',
          'image_id',
          'publication',
          'shopee_url',
          'tokopedia_url',
          'whatsapp_url',
        ]),
      );
      expect(payload.containsKey('economics'), isFalse);
    });
    test(
      'two-column action order and archived history visibility are preserved',
      () {
        final feature = features['products']!;
        expect(
          feature.actions(RecordData(product), data, owner).map((a) => a.label),
          ['Edit', 'Riwayat', 'Harga / HPP', 'Nonaktifkan'],
        );
        final archived = RecordData({...product, 'archived': true});
        expect(feature.actions(archived, data, owner).map((a) => a.label), [
          'Riwayat',
        ]);
        expect(feature.cells(archived).last.badge, 'Nonaktif');
      },
    );
    test('Grade A panel updates exact settings contract while preserving unrelated operational settings', () {
      final form = gradeAForm(RecordData(organization));
      final result = form.payload(
        form.initialValues()..['grade_a_price_rp'] = '17000',
      );
      expect(result['grade_a_price_rp'], '17000');
      expect(result['reminder_time'], '19:00');
      expect(result['timezone'], 'Asia/Jakarta');
      expect(result['reminders_enabled'], true);
      expect(
        result.keys,
        unorderedEquals([
          'name',
          'timezone',
          'reminder_time',
          'reminders_enabled',
          'reminder_email',
          'grade_a_price_rp',
          'grade_a_hpp_rp',
        ]),
      );
    });
  });
  group('Planning versus actual production', () {
    for (final status in ['OPEN', 'NEEDS_REVIEW']) {
      test('$status plan can change, record actual results or cancel', () {
        final row = RecordData({...plan, 'status': status});
        expect(planFeature.actions(row, data, admin).map((a) => a.label), [
          'Ubah',
          'Catat hasil',
          'Batalkan',
        ]);
      });
    }
    for (final status in ['COMPLETED', 'CANCELLED']) {
      test(
        '$status plan has no mutable controls',
        () => expect(
          planFeature.actions(
            RecordData({...plan, 'status': status}),
            data,
            owner,
          ),
          isEmpty,
        ),
      );
    }
    test('plan payload contains planned quantity and no inventory mutation or actual quantities', () {
      final form = planForm(data, RecordData(plan));
      final payload = form.payload(form.initialValues());
      expect(payload, {
        'product_id': productId,
        'business_date': today,
        'planned_g': '100000',
        'notes': '',
      });
      expect(form.path, '/production/plans/$recordId');
    });
    test('actual production may differ from plan and posts to existing actual-batch endpoint', () {
      final form = productionForm(data, RecordData(plan));
      final payload = form.payload(
        form.initialValues()
          ..addAll({'actual_g': '110', 'output_units': '400'}),
      );
      expect(form.path, '/production/batches');
      expect(payload['actual_g'], '110000');
      expect(payload['plan_id'], recordId);
      expect(payload['product_id'], productId);
      expect(payload.containsKey('theoretical_g'), isFalse);
      expect(
        productionFeature.cells(RecordData(batch))[2].secondary.last,
        'Selisih 10 kg',
      );
    });
    test('production cancellation only exists for completed batches', () {
      expect(
        productionFeature
            .actions(RecordData(batch), data, owner)
            .single
            .form!
            .path,
        '/production/batches/$recordId/void',
      );
      expect(
        productionFeature.actions(
          RecordData({...batch, 'status': 'VOIDED'}),
          data,
          owner,
        ),
        isEmpty,
      );
    });
  });
  group('Stock count conditional validation', () {
    test('matching count always sends reason null and disables/clears reason input', () {
      final row = RecordData(opname);
      final form = completeOpnameForm(row);
      final values = form.initialValues()
        ..addAll({'physical_quantity': '1000', 'reason': 'MISSING_GOODS'});
      expect(form.fields[1].enabled!(values), isFalse);
      form.normalize!(values);
      expect(values['reason'], '');
      expect(form.payload(values), {
        'physical_quantity': '1000000',
        'reason': null,
        'notes': '',
      });
      expect(form.summary!(values), 'Selisih 0 kg');
      expect(form.fields[1].choices.any((c) => c.label == 'Sesuai'), isFalse);
    });
    test(
      'discrepancy needs a supported reason and OTHER needs explanatory notes',
      () {
        final form = completeOpnameForm(RecordData(opname));
        final values = form.initialValues()..['physical_quantity'] = '999,5';
        expect(form.fields[1].enabled!(values), isTrue);
        expect(() => form.payload(values), throwsFormatException);
        values['reason'] = 'OTHER';
        expect(() => form.payload(values), throwsFormatException);
        values['notes'] = 'Selisih setelah ditimbang ulang';
        expect(form.payload(values)['physical_quantity'], '999500');
        expect(form.payload(values)['reason'], 'OTHER');
        expect(form.summary!(values), 'Selisih -0,5 kg');
      },
    );
    test('finished stock count uses integer units and exposes explicit refresh/recount', () {
      final row = RecordData({
        ...opname,
        'kind': 'FINISHED',
        'baseline_quantity': '12',
      });
      final form = completeOpnameForm(row);
      expect(form.fields.first.kind, InputKind.integer);
      expect(
        form.payload(
          form.initialValues()..['physical_quantity'] = '12',
        )['reason'],
        isNull,
      );
      final actions = opnameFeature.actions(row, data, admin);
      expect(actions[1].label, 'Gunakan stok terbaru');
      expect(actions[1].form!.path, '/opnames/$recordId/refresh');
    });
    test('completed matching count is informational text and not a button', () {
      final row = RecordData({
        ...opname,
        'status': 'COMPLETED',
        'physical_quantity': '1000000',
        'difference': '0',
      });
      expect(opnameFeature.actions(row, data, owner), isEmpty);
      expect(opnameFeature.cells(row).last.informational, isTrue);
      expect(opnameFeature.cells(row).last.primary, 'Sesuai');
    });
  });
  group('Sales snapshots and daily confirmation', () {
    test(
      'Grade A converts kg, default price omitted, actual zero price preserved',
      () {
        final rows = inventory.map(RecordData.new).toList();
        expect(
          saleLinePayload(
            SaleDraftLine(itemId: gradeAId, quantity: '1,025'),
            rows,
          ),
          {'item_id': gradeAId, 'quantity': '1025'},
        );
        expect(
          saleLinePayload(
            SaleDraftLine(itemId: finishedId, quantity: '2', price: '0'),
            rows,
          ),
          {'item_id': finishedId, 'quantity': '2', 'unit_price_rp': '0'},
        );
        expect(
          () => saleLinePayload(
            SaleDraftLine(itemId: gradeBId, quantity: '1'),
            rows,
          ),
          throwsFormatException,
        );
        expect(
          () => saleLinePayload(
            SaleDraftLine(itemId: finishedId, quantity: '1,5'),
            rows,
          ),
          throwsFormatException,
        );
      },
    );
    test('sale details and cancellation use server endpoints, never local history edits', () {
      final actions = saleFeature.actions(RecordData(sale), data, admin);
      expect(actions[0].detail!.type, 'sale');
      expect(actions[1].form!.path, '/sales/$recordId/void');
      expect(
        saleFeature
            .actions(RecordData({...sale, 'status': 'VOIDED'}), data, owner)
            .map((a) => a.label),
        ['Rincian'],
      );
    });
    test('COMPLETED and NO_SALES confirmations use server business date', () {
      for (final status in ['COMPLETED', 'NO_SALES']) {
        final form = salesConfirmation(RecordData(notification), status);
        expect(form.payload({}), {'business_date': today, 'status': status});
        expect(form.path, '/sales-day/confirm');
      }
    });
  });
  group('Authorization, publication, audit and navigation', () {
    test('Owner alone can invite and manage Admin; transfer requires current password', () {
      expect(userFeature.ownerCreate, isTrue);
      expect(userFeature.actions(RecordData(adminRow), data, admin), isEmpty);
      expect(userFeature.actions(RecordData(userRow), data, owner), isEmpty);
      final active = userFeature.actions(RecordData(adminRow), data, owner);
      expect(active.map((a) => a.label), ['Jadikan Owner', 'Nonaktifkan']);
      expect(active.first.form!.fields.single.name, 'current_password');
      expect(active.first.form!.afterSave, AfterSave.verifySession);
      expect(
        userFeature
            .actions(RecordData({...adminRow, 'active': false}), data, owner)
            .map((a) => a.label),
        ['Aktifkan'],
      );
    });
    test(
      'farmer archive leaves publication/history only and audit cannot mutate',
      () {
        final feature = features['farmers']!;
        expect(
          feature.actions(
            RecordData({...farmer, 'archived': true}),
            data,
            admin,
          ),
          isEmpty,
        );
        expect(features['audit']!.create, isNull);
        expect(
          features['audit']!
              .actions(RecordData(audit), data, owner)
              .single
              .detail!
              .type,
          'audit',
        );
      },
    );
    test('all fourteen menus retain canonical route order and terminology', () {
      expect(destinations.map((d) => d.label), [
        'Ringkasan',
        'Panen',
        'Persediaan',
        'Produk & HPP',
        'Rencana produksi',
        'Hasil produksi',
        'Cek stok fisik',
        'Penjualan',
        'Pembukuan',
        'Konten website',
        'Pengguna',
        'Anggota tani',
        'Riwayat aktivitas',
        'Pengaturan',
      ]);
      expect(destinations.map((d) => d.path).toSet().length, 14);
    });
  });
  group('Riverpod provider state and backend contract', () {
    late TestHarness h;
    setUp(() async {
      h = TestHarness();
      await h.container.read(authProvider.notifier).restore();
    });
    tearDown(() => h.dispose());
    for (final id in features.keys) {
      test(
        '$id loads from existing API and validates its main response',
        () async {
          final provider = featureProvider((id, 0));
          final subscription = h.container.listen(provider, (_, next) {});
          addTearDown(subscription.close);
          final result = await h.container.read(provider.future);
          expect(result.page.items, isNotEmpty);
          expect(result.today, today);
          expect(
            h.server.adapter.requests.every((r) => r.method == 'GET'),
            isTrue,
          );
        },
      );
    }
    test('malformed inventory is an error state rather than fabricated zero balances', () async {
      h.server.overrides['GET /inventory'] = (_) => const Reply([
        {
          'id': gradeAId,
          'name': 'Test',
          'kind': 'GRADE_A',
          'balance': 1.5,
          'planned_g': '0',
        },
      ]);
      final provider = featureProvider(('inventory', 0));
      final subscription = h.container.listen(provider, (_, next) {});
      addTearDown(subscription.close);
      await expectLater(
        h.container.read(provider.future),
        throwsA(isA<AppError>()),
      );
      expect(h.container.read(provider).hasError, isTrue);
    });
    test('pagination forwards exact offset and server next_offset', () async {
      h.server.overrides['GET /harvests'] = (r) {
        expect(r.uri.queryParameters, {'limit': '30', 'offset': '30'});
        return Reply(page([harvest], next: 60));
      };
      final provider = featureProvider(('harvests', 30));
      final subscription = h.container.listen(provider, (_, next) {});
      addTearDown(subscription.close);
      expect((await h.container.read(provider.future)).page.nextOffset, 60);
    });
  });
}
