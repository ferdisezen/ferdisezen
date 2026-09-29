import 'package:flutter/material.dart';

import 'staff_login/staff_login_screen.dart';

void main() => runApp(const VelarPosApp());

class VelarPosApp extends StatelessWidget {
  const VelarPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VelarMenu POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0F9F83)),
      home: StaffLoginScreen(
        appVersion: 'v2.4.0',
        supportPhone: '0850 000 00 00',
        // Demo: 1234 doğru PIN. Gerçek uygulamada burada sunucu doğrulaması yapılır.
        onSubmit: (pin) async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return pin == '1234';
        },
      ),
    );
  }
}
