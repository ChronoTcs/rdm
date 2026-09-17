import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform-adaptive icon provider:
/// - iOS: Apple Cupertino icons ([CupertinoIcons])
/// - Windows and all other platforms: Google Material Design icons ([Icons])
abstract final class AdaptiveIcons {
  static bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

  // Navigation & Category Icons
  static IconData get allInbox => isIos ? CupertinoIcons.tray_2 : Icons.all_inbox_outlined;
  static IconData get downloading => isIos ? CupertinoIcons.arrow_down_circle : Icons.downloading_outlined;
  static IconData get pauseCircle => isIos ? CupertinoIcons.pause_circle : Icons.pause_circle_outline;
  static IconData get checkCircle => isIos ? CupertinoIcons.checkmark_circle : Icons.check_circle_outline;
  static IconData get folderZip => isIos ? CupertinoIcons.archivebox : Icons.folder_zip_outlined;
  static IconData get video => isIos ? CupertinoIcons.film : Icons.movie_outlined;
  static IconData get audio => isIos ? CupertinoIcons.music_note : Icons.music_note_outlined;
  static IconData get documents => isIos ? CupertinoIcons.doc_text : Icons.description_outlined;
  static IconData get programs => isIos ? CupertinoIcons.macwindow : Icons.terminal_outlined;
  static IconData get folder => isIos ? CupertinoIcons.folder : Icons.folder_outlined;

  // Actions & Controls
  static IconData get bolt => isIos ? CupertinoIcons.bolt_fill : Icons.bolt;
  static IconData get search => isIos ? CupertinoIcons.search : Icons.search;
  static IconData get add => isIos ? CupertinoIcons.add : Icons.add;
  static IconData get play => isIos ? CupertinoIcons.play_arrow_solid : Icons.play_arrow;
  static IconData get pause => isIos ? CupertinoIcons.pause_solid : Icons.pause;
  static IconData get delete => isIos ? CupertinoIcons.trash : Icons.delete_outline;
  static IconData get settings => isIos ? CupertinoIcons.gear_alt : Icons.settings_outlined;
  static IconData get tune => isIos ? CupertinoIcons.slider_horizontal_3 : Icons.tune;
  static IconData get refresh => isIos ? CupertinoIcons.arrow_clockwise : Icons.refresh;
  static IconData get close => isIos ? CupertinoIcons.xmark : Icons.close;
  static IconData get download => isIos ? CupertinoIcons.arrow_down_to_line : Icons.download;
  static IconData get downloadDone => isIos ? CupertinoIcons.checkmark_seal : Icons.download_done_outlined;
  static IconData get dropTarget => isIos ? CupertinoIcons.arrow_down_square : Icons.vertical_align_bottom;

  // Status Indicators
  static IconData get arrowDownward => isIos ? CupertinoIcons.arrow_down : Icons.arrow_downward;
  static IconData get check => isIos ? CupertinoIcons.checkmark : Icons.check;
  static IconData get error => isIos ? CupertinoIcons.exclamationmark_circle : Icons.error_outline;
  static IconData get linkOff => isIos ? CupertinoIcons.link : Icons.link_off;
  static IconData get schedule => isIos ? CupertinoIcons.clock : Icons.schedule;
}
