import 'package:flutter_test/flutter_test.dart';

import 'package:match_it_app/main.dart';

void main() {
  testWidgets('App launches login page', (WidgetTester tester) async {
    await tester.pumpWidget(const MatchItApp());

    expect(find.text('Welcome to MATCHit'), findsOneWidget);
  });
}
