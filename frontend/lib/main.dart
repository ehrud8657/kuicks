import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_shell.dart';
import 'theme.dart';

void main() => runApp(const KuicsApp());

class KuicsApp extends StatelessWidget {
  const KuicsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'KUICS',
        debugShowCheckedModeBanner: false,
        // 날짜·시간 선택창과 기본 버튼 문구를 한국어로 표시한다.
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildAppTheme(Theme.of(context).textTheme),
        home: const SiteShell(),
      );
}
