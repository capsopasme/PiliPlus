import 'package:material_ui/material_ui.dart';

/// 评论区配色：与简介页同底色（不画背景），文字取主题色；
/// 楼中楼放在比底色略深一点的圆角卡片里。
///
/// 半透明只是颜色自带 alpha，按纯色绘制；不使用 BackdropFilter 实时模糊。
@immutable
class ReplyPalette {
  const ReplyPalette({
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.divider,
    required this.subCard,
    required this.subDivider,
    required this.fill,
    required this.headerBackground,
    required this.link,
  });

  /// 评论正文、昵称
  final Color label;

  /// 时间、属地、赞数
  final Color secondaryLabel;

  /// 更弱的文字/图标
  final Color tertiaryLabel;

  /// 一级评论之间的细线
  final Color divider;

  /// 楼中楼的圆角卡片
  final Color subCard;

  /// 楼中楼卡片内各条回复之间的细线
  final Color subDivider;

  /// 骨架占位
  final Color fill;

  /// 悬浮排序栏底色（半透明）
  final Color headerBackground;

  /// 链接、@、话题、「共 N 条回复」等
  final Color link;

  static ReplyPalette? _cache;
  static ColorScheme? _cacheScheme;
  static Color? _cacheCanvas;

  static ReplyPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canvas = theme.canvasColor;
    final cached = _cache;
    if (cached != null &&
        identical(_cacheScheme, colorScheme) &&
        _cacheCanvas == canvas) {
      return cached;
    }
    _cacheScheme = colorScheme;
    _cacheCanvas = canvas;
    return _cache = _build(colorScheme, canvas);
  }

  static ReplyPalette _build(ColorScheme colorScheme, Color canvas) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final onSurface = colorScheme.onSurface;
    return ReplyPalette(
      label: onSurface,
      secondaryLabel: colorScheme.outline,
      tertiaryLabel: colorScheme.outline.withValues(alpha: 0.75),
      divider: onSurface.withValues(alpha: isDark ? 0.10 : 0.07),
      // 与底色混合后的不透明色：卡片内再画细线/文字不会叠出色差
      subCard: Color.alphaBlend(
        Color.lerp(
          onSurface,
          colorScheme.primary,
          0.25,
        )!.withValues(alpha: isDark ? 0.07 : 0.045),
        canvas,
      ),
      subDivider: onSurface.withValues(alpha: isDark ? 0.09 : 0.06),
      fill: onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
      headerBackground: canvas.withValues(alpha: 0.94),
      link: colorScheme.primary,
    );
  }
}

/// 一级评论之间的半透明细线（1 个物理像素，左侧与正文对齐）
class ReplyDivider extends StatelessWidget {
  const ReplyDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: ReplyStyle.rootPadding + ReplyStyle.contentIndent,
        right: ReplyStyle.rootPadding,
      ),
      child: SizedBox(
        height: 1 / MediaQuery.devicePixelRatioOf(context),
        width: double.infinity,
        child: ColoredBox(color: color),
      ),
    );
  }
}

/// 评论区排版常量（按原设计图相对屏幕宽度换算）
abstract final class ReplyStyle {
  /// 一级评论左右留白（不包卡片）
  static const double rootPadding = 16;

  /// 楼中楼卡片：圆角矩形（RRect，绘制走快速路径）
  static const BorderRadius subCardRadius = BorderRadius.all(
    Radius.circular(13),
  );

  /// 楼中楼面板里单独成卡的次级评论
  static const EdgeInsets subCardMargin = EdgeInsets.fromLTRB(16, 0, 16, 8);

  static const EdgeInsets subCardPadding = EdgeInsets.fromLTRB(10, 9, 10, 9);

  /// 一级评论下方楼中楼卡片的内边距
  static const EdgeInsets threadCardPadding = EdgeInsets.fromLTRB(9, 2, 9, 2);

  /// 主评论头像
  static const double avatarSize = 32;

  /// 头像与正文的间距；正文、楼中楼卡片都从这里开始缩进
  static const double avatarGap = 12;

  static const double contentIndent = avatarSize + avatarGap;

  /// 楼中楼头像
  static const double subAvatarSize = 19;

  static const double subAvatarGap = 9;

  static const double subContentIndent = subAvatarSize + subAvatarGap;

  static const TextStyle name = TextStyle(
    fontSize: 12.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle subName = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 10,
    height: 1.3,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 评论正文（一级）
  static const TextStyle content = TextStyle(
    fontSize: 13,
    height: 1.55,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 评论正文（次级）
  static const TextStyle subContent = TextStyle(
    fontSize: 12,
    height: 1.5,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle action = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
