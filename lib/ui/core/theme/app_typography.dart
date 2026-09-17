import 'package:flutter/material.dart';

class AppTypography {
  static const TextStyle displayHeading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle tableCellPrimary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tableCellSecondary = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  /// Metric style with FontFeature.tabularFigures() to eliminate jitter during line-rate updates.
  static const TextStyle dataMetricStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: -0.2,
  );

  static const TextStyle tooltip = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
  );
}
