import 'package:material_ui/material_ui.dart';

/// 评论区 iOS 风格配色与排版。
///
/// 浅色：iOS systemGroupedBackground 底色 + 半透明白色圆角卡片 + 系统级灰阶文字；
/// 深色：沿用应用当前的 surface 作底色（纯黑模式下即为 iOS 的纯黑），卡片取 iOS 深色分组色。
///
/// 卡片的"半透明"只是颜色自带 alpha，直接按纯色绘制，
/// 不使用 BackdropFilter 实时模糊，滚动时没有额外的离屏合成开销。
@immutable
class ReplyPalette {
  const ReplyPalette({
    required this.background,
    required this.card,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.thread,
    required this.fill,
  });

  /// 卡片下方的分组底色
  final Color background;

  /// 半透明卡片
  final Color card;

  /// 主要文字
  final Color label;

  /// 次要文字（时间、属地、赞数）
  final Color secondaryLabel;

  /// 更弱的文字/图标
  final Color tertiaryLabel;

  /// 楼中楼左侧竖线
  final Color thread;

  /// 弱填充（骨架、标签底）
  final Color fill;

  static const light = ReplyPalette(
    background: Color(0xFFF2F2F7),
    card: Color(0xD9FFFFFF),
    label: Color(0xFF1C1C1E),
    secondaryLabel: Color(0x993C3C43),
    tertiaryLabel: Color(0x4D3C3C43),
    thread: Color(0x293C3C43),
    fill: Color(0x123C3C43),
  );

  static ReplyPalette _dark(Color surface) => ReplyPalette(
    background: surface,
    card: const Color(0xD91C1C1E),
    label: const Color(0xFFF2F2F7),
    secondaryLabel: const Color(0x99EBEBF5),
    tertiaryLabel: const Color(0x4DEBEBF5),
    thread: const Color(0x3DEBEBF5),
    fill: const Color(0x1FEBEBF5),
  );

  static ReplyPalette? _cachedDark;

  static ReplyPalette of(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    if (colorScheme.brightness == Brightness.light) {
      return light;
    }
    final surface = colorScheme.surface;
    final cached = _cachedDark;
    if (cached != null && cached.background == surface) {
      return cached;
    }
    return _cachedDark = _dark(surface);
  }
}

/// 评论区排版常量
abstract final class ReplyStyle {
  /// iOS 连续曲率圆角
  static const ShapeBorder cardShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  /// 卡片外边距（卡片之间留 8 的间隔）
  static const EdgeInsets cardMargin = EdgeInsets.fromLTRB(12, 0, 12, 8);

  /// 卡片内边距
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(14, 12, 14, 12);

  /// 主评论头像
  static const double avatarSize = 32;

  /// 头像与正文的间距；正文、楼中楼都从这里开始缩进
  static const double avatarGap = 10;

  static const double contentIndent = avatarSize + avatarGap;

  /// 楼中楼头像
  static const double subAvatarSize = 20;

  static const double subAvatarGap = 6;

  static const double subContentIndent = subAvatarSize + subAvatarGap;

  static const TextStyle name = TextStyle(
    fontSize: 13.5,
    height: 1.25,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle subName = TextStyle(
    fontSize: 12.5,
    height: 1.25,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 11.5,
    height: 1.25,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle content = TextStyle(
    fontSize: 15,
    height: 1.5,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle subContent = TextStyle(
    fontSize: 14,
    height: 1.5,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle action = TextStyle(
    fontSize: 12.5,
    height: 1.25,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
