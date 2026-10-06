import 'package:PiliPlus/models/common/enum_with_label.dart';

enum AudioOutput implements EnumWithLabel {
  opensles('OpenSL ES'),
  aaudio('AAudio'),
  audiotrack('AudioTrack'),
  ;

  /// 默认优先 AudioTrack（与 mpv-android 一致）：
  /// - mpv 的 OpenSL ES 输出在跳转时只 Clear 缓冲队列而不暂停，系统 AudioTrack
  ///   在播放状态下会忽略 flush，旧音频尾巴与新音频硬拼接，产生「啪嗒」声；
  ///   AudioTrack 输出跳转时 pause + flush，系统会做淡出；
  /// - OpenSL ES 播放器默认请求低延迟（FAST）通路，AudioTrack 以媒体用途创建，
  ///   系统可走 deep buffer，CPU 唤醒更少，更省电。
  static const defaultValue = 'audiotrack,opensles,aaudio';

  /// 旧版默认值（按枚举顺序），视同未设置
  static const legacyDefaultValue = 'opensles,aaudio,audiotrack';

  @override
  final String label;
  const AudioOutput(this.label);
}
