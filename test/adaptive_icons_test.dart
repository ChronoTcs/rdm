import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdm/ui/core/theme/adaptive_icons.dart';

void main() {
  group('AdaptiveIcons platform switching', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('Uses Material icons on Windows and other platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(AdaptiveIcons.isIos, isFalse);
      expect(AdaptiveIcons.allInbox, equals(Icons.all_inbox_outlined));
      expect(AdaptiveIcons.bolt, equals(Icons.bolt));
      expect(AdaptiveIcons.search, equals(Icons.search));
      expect(AdaptiveIcons.add, equals(Icons.add));
      expect(AdaptiveIcons.play, equals(Icons.play_arrow));
      expect(AdaptiveIcons.pause, equals(Icons.pause));
      expect(AdaptiveIcons.delete, equals(Icons.delete_outline));
      expect(AdaptiveIcons.settings, equals(Icons.settings_outlined));
      expect(AdaptiveIcons.download, equals(Icons.download));
    });

    test('Uses Cupertino icons on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AdaptiveIcons.isIos, isTrue);
      expect(AdaptiveIcons.allInbox, equals(CupertinoIcons.tray_2));
      expect(AdaptiveIcons.bolt, equals(CupertinoIcons.bolt_fill));
      expect(AdaptiveIcons.search, equals(CupertinoIcons.search));
      expect(AdaptiveIcons.add, equals(CupertinoIcons.add));
      expect(AdaptiveIcons.play, equals(CupertinoIcons.play_arrow_solid));
      expect(AdaptiveIcons.pause, equals(CupertinoIcons.pause_solid));
      expect(AdaptiveIcons.delete, equals(CupertinoIcons.trash));
      expect(AdaptiveIcons.settings, equals(CupertinoIcons.gear_alt));
      expect(AdaptiveIcons.download, equals(CupertinoIcons.arrow_down_to_line));
    });
  });
}
