import 'dart:io' show Platform;

import 'package:PiliPlus/models/video/play/url.dart' show Volume;
import 'package:PiliPlus/utils/storage_pref.dart';

/// 音量均衡（仅 Android）。
///
/// 只做「整段固定增益」：按 B站 返回的响度测量值（playurl 的 volume，
/// 请求时带 voice_balance=1）算出一个 dB 值，交给 mpv 的 volume-gain 在输出端
/// 统一乘上。增益上限受真峰值约束，提升音量也不会削波，因此不需要压限器。
///
/// 旧实现用 --lavfi-complex 挂 loudnorm/dynaudnorm：
/// - 每次跳转 mpv 都会销毁重建滤镜图，有状态的滤镜重新估计增益，导致音量突变/爆音；
/// - loudnorm 在动态模式下强制把音频升采样到 192kHz 处理，再降回输出采样率，非常耗电；
///   而旧参数把 TP 限制为不超过测得的真峰值，凡是需要提升音量的视频都会落入动态模式；
/// - lavfi-complex 接管了音轨选择，只在 DASH 分离音轨时生效，MP4/离线单文件不生效。
mixin AudioNormalizationMixin {
  late final bool enableAudioNormalization =
      Platform.isAndroid && Pref.audioNormalization;

  /// 若开启音量均衡且 [volume] 有效，把增益写入 [map]（mpv 的单文件选项，
  /// 切换到下一个视频时自动恢复）。
  Map<String, String>? audioNormalizationExtras(
    Volume? volume, {
    Map<String, String>? map,
  }) {
    if (!enableAudioNormalization) return map;
    final gain = volume?.normalizationGain;
    if (gain == null) return map;
    return (map ?? <String, String>{})
      ..['volume-gain'] = gain.toStringAsFixed(2);
  }
}
