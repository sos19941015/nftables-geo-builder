import 'package:flutter_test/flutter_test.dart';

import 'package:plop_clone_flutter/main.dart';

void main() {
  testWidgets('renders nftables script generator', (tester) async {
    await tester.pumpWidget(const NftablesScriptGeneratorApp());

    expect(find.text('Linux nftables \u81ea\u52d5\u5316\u90e8\u7f72\u8173\u672c\u7522\u751f\u5668'), findsOneWidget);
    expect(find.text('Bash \u8173\u672c\u9810\u89bd'), findsOneWidget);
    expect(find.text('\u4e00\u9375\u8907\u88fd'), findsOneWidget);
  });
}
