import 'package:flutter_test/flutter_test.dart';

import 'package:photolite_flutter/main.dart';

void main() {
  testWidgets('PhotoLite renders the start screen', (tester) async {
    await tester.pumpWidget(const PhotoLiteApp());

    expect(find.text('PhotoLite'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
