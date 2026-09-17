import 'package:flutter_test/flutter_test.dart';
import 'package:rdm/di/injection_container.dart';
import 'package:rdm/main.dart';

void main() {
  testWidgets('RdmApp renders header bar and empty state', (WidgetTester tester) async {
    await configureDependencies();
    await tester.pumpWidget(const RdmApp());
    await tester.pump();

    // Verify Brand title is visible
    expect(find.text('RDM'), findsOneWidget);
    // Verify Add URL button is visible
    expect(find.text('Add URL'), findsOneWidget);
    // Verify Sidebar "All Downloads" is visible
    expect(find.text('All Downloads'), findsOneWidget);
  });
}
