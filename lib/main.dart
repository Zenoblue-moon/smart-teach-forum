import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 沉浸式：状态栏与系统导航栏透明，内容延伸（edge-to-edge）。
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final auth = AuthState();
  final settings = SettingsState();
  await Future.wait([auth.load(), settings.load()]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const SmartTeachApp(),
    ),
  );
}
