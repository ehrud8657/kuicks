import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'theme.dart';

void main() => runApp(const KuicsApp());

class KuicsApp extends StatelessWidget {
  const KuicsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = AppColors.navy;
    const crimson = AppColors.crimson;
    return MaterialApp(
      title: 'KUICS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: crimson, primary: crimson),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: Theme.of(context).textTheme.apply(
              bodyColor: navy,
              displayColor: navy,
              fontFamily: 'sans-serif',
            ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
      ),
      home: const SiteShell(),
    );
  }
}
