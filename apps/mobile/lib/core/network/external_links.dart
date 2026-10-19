import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../config/app_config.dart';
import '../errors/app_error.dart';

class ExternalLinks {
  const ExternalLinks(this.config);
  final AppConfig config;
  Future<void> website() async {
    final uri = Uri.parse(config.appOrigin);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const AppError('Website belum dapat dibuka. Coba lagi.');
    }
  }
  Future<void> privacy() async {
    final uri = Uri.parse(config.appOrigin).resolve('/privacy');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const AppError('Kebijakan Privasi belum dapat dibuka. Coba lagi.');
    }
  }
}

final externalLinksProvider = Provider<ExternalLinks>(
  (ref) => ExternalLinks(ref.watch(configProvider)),
);
