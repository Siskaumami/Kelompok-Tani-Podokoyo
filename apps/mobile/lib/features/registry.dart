import '../core/data/feature_spec.dart';
import 'harvests/data/harvest_feature.dart';
import 'farmers/data/farmer_feature.dart';
import 'inventory/data/inventory_feature.dart';
import 'production_plans/data/plan_feature.dart';
import 'production/data/production_feature.dart';
import 'products/data/product_feature.dart';
import 'stock_opname/data/opname_feature.dart';
import 'sales/data/sales_feature.dart';
import 'users/data/user_feature.dart';
import 'audit/data/audit_feature.dart';

final features = <String, FeatureSpec>{
  'harvests': harvestFeature,
  'farmers': farmerFeature,
  'inventory': inventoryFeature,
  'plans': planFeature,
  'production': productionFeature,
  'products': productFeature,
  'opnames': opnameFeature,
  'sales': saleFeature,
  'users': userFeature,
  'audit': auditFeature,
};
