import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:collection/collection.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// 播放期间临时限制屏幕刷新率，降低屏幕刷新与 Flutter 合成（含弹幕动画）的功耗。
/// 退出播放后恢复为用户在「屏幕帧率设置」中选择的模式（未设置则为系统自动）。
abstract final class DisplayModeUtils {
  static bool _limited = false;

  static Future<void> limitForPlayback({double targetRefreshRate = 60}) async {
    if (_limited) return;
    _limited = true;
    try {
      final modes = await FlutterDisplayMode.supported;
      final active = await FlutterDisplayMode.active;
      DisplayMode? best;
      for (final mode in modes) {
        // 跳过「自动」，且保持当前分辨率
        if (mode.id == 0 ||
            mode.width != active.width ||
            mode.height != active.height) {
          continue;
        }
        if (best == null ||
            (mode.refreshRate - targetRefreshRate).abs() <
                (best.refreshRate - targetRefreshRate).abs()) {
          best = mode;
        }
      }
      if (best != null && _limited) {
        await FlutterDisplayMode.setPreferredMode(best);
      }
    } catch (_) {}
  }

  static Future<void> restore() async {
    if (!_limited) return;
    _limited = false;
    try {
      var mode = DisplayMode.auto;
      final String? stored = GStorage.setting.get(SettingBoxKey.displayMode);
      if (stored != null) {
        final modes = await FlutterDisplayMode.supported;
        mode =
            modes.firstWhereOrNull((e) => e.toString() == stored) ??
            DisplayMode.auto;
      }
      if (!_limited) {
        await FlutterDisplayMode.setPreferredMode(mode);
      }
    } catch (_) {}
  }
}
