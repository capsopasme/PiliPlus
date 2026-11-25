import 'dart:io' show Platform;

import 'package:flutter/services.dart' show MethodChannel;

/// Android 窗口相关的小工具（对应 MainActivity 里的 `piliplus/window` 通道）
abstract final class WindowUtils {
  static const _channel = MethodChannel('piliplus/window');

  static bool _videoBackground = false;

  /// 播放页期间把窗口底色设为黑色。
  ///
  /// 旋转、全屏切换时 Flutter 画面按新尺寸重绘之前，露出来的是窗口底色；
  /// 浅色主题下它是白色，切换瞬间会闪一下白边。离开播放页后恢复原底色。
  static void setVideoBackground(bool enable) {
    if (!Platform.isAndroid || _videoBackground == enable) {
      return;
    }
    _videoBackground = enable;
    _channel
        .invokeMethod<void>('setVideoBackground', enable)
        .catchError((_) {});
  }
}
