import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wallet/financial_tracker_app/providers/transaction_provider.dart';
import 'package:wallet/homepage.dart';

void main() {
  setUpAll(() {
    // Initialize ffi implementation for sqflite so tests can open databases
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App provides TransactionProvider to HomePage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ],
        child: MaterialApp(home: HomePage()),
      ),
    );

    // Allow provider init to run
    await tester.pumpAndSettle();

    // Verify HomePage can access provider by finding the summary text
    expect(find.textContaining('الوضع المالي الفعلي'), findsOneWidget);
  });
}
