import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdm/domain/models/app_settings.dart';
import 'package:rdm/domain/models/download_task.dart';
import 'package:rdm/ui/core/theme/color_tokens.dart';
import 'package:rdm/ui/core/widgets/activity_rail.dart';
import 'package:rdm/ui/core/widgets/island_card.dart';
import 'package:rdm/ui/core/widgets/sidebar_navigation.dart';
import 'package:rdm/ui/features/download_list/view_models/download_list_view_model.dart';

void main() {
  group('Modern UI Component Suite', () {
    testWidgets('IslandCard renders child with diffused shadows and custom styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IslandCard(
              child: const Text('Bento Island Child'),
            ),
          ),
        ),
      );

      expect(find.text('Bento Island Child'), findsOneWidget);
    });

    testWidgets('ActivityRail renders view tabs and Sun/Moon toggle capsule', (tester) async {
      var isDark = true;
      var selectedView = RailViewMode.downloads;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: ActivityRail(
                  currentView: selectedView,
                  onSelectView: (v) => setState(() => selectedView = v),
                  isDark: isDark,
                  onToggleTheme: () => setState(() => isDark = !isDark),
                ),
              ),
            );
          },
        ),
      );

      // Verify Sun / Moon toggle icons are present
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);

      // Tap theme switcher
      await tester.tap(find.byIcon(Icons.light_mode));
      await tester.pump();
      expect(isDark, isFalse);
    });

    testWidgets('SidebarNavigation renders dynamic badges and category pills', (tester) async {
      var status = StatusFilter.all;
      TaskCategory? category;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarNavigation(
              selectedStatusFilter: status,
              selectedCategory: category,
              onSelectStatus: (s) => status = s,
              onSelectCategory: (c) => category = c,
              countAll: 5,
              countDownloading: 2,
              countPaused: 1,
              countCompleted: 2,
            ),
          ),
        ),
      );

      expect(find.text('All Downloads'), findsOneWidget);
      expect(find.text('Downloading'), findsOneWidget);
      expect(find.text('Compressed'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Fast Storage'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
    });
  });
}
