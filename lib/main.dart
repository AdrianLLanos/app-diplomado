import 'package:flutter/widgets.dart';
import 'core/api/clinic_api.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  ClinicApi.instance = ClinicApi(config: config);
  runApp(DentalClinicApp(config: config));
}
