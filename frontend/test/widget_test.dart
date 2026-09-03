import 'package:flutter_test/flutter_test.dart';
import 'package:kuics_frontend/main.dart';

void main() {
  testWidgets('home renders main content', (tester) async {
    await tester.pumpWidget(const KuicsApp());
    expect(find.text('보안을 배우고,\n함께 성장합니다.'), findsOneWidget);
    expect(find.text('KUICS NOW'), findsOneWidget);
  });
}
