import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/models/common/reply/reply_background_type.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

export 'package:PiliPlus/models/common/reply/reply_background_type.dart';

/// 评论区配色。
///
/// - 羊皮纸（仅浅色模式）：羊皮纸图片作底，深棕墨色文字，次级评论用奶油色半透明卡片；
/// - 与简介相同（以及深色模式下的羊皮纸设置）：不画背景，直接透出页面底色，
///   文字取主题色。
///
/// 半透明只是颜色自带 alpha，按纯色绘制；不使用 BackdropFilter 实时模糊。
@immutable
class ReplyPalette {
  const ReplyPalette({
    required this.parchment,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.divider,
    required this.subCard,
    required this.fill,
    required this.headerBackground,
    required this.link,
  });

  /// 是否绘制羊皮纸背景
  final bool parchment;

  /// 评论正文、昵称
  final Color label;

  /// 时间、属地、赞数
  final Color secondaryLabel;

  /// 更弱的文字/图标
  final Color tertiaryLabel;

  /// 一级评论之间的细线
  final Color divider;

  /// 次级评论的半透明圆角卡片
  final Color subCard;

  /// 骨架占位
  final Color fill;

  /// 悬浮排序栏底色（半透明）
  final Color headerBackground;

  /// 链接、@、话题等
  final Color link;

  /// 当前背景设置，修改后评论区立即刷新
  static final ValueNotifier<ReplyBackgroundType> backgroundType =
      ValueNotifier(Pref.replyBackground);

  static ReplyPalette? _parchmentCache;
  static ReplyPalette? _themeCache;
  static ColorScheme? _themeCacheScheme;
  static Color? _themeCacheCanvas;

  static ReplyPalette of(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (backgroundType.value == ReplyBackgroundType.parchment &&
        colorScheme.brightness == Brightness.light) {
      final cached = _parchmentCache;
      if (cached != null && cached.link == _parchmentLink(colorScheme)) {
        return cached;
      }
      return _parchmentCache = _parchmentPalette(colorScheme);
    }
    final canvas = theme.canvasColor;
    final cached = _themeCache;
    if (cached != null &&
        identical(_themeCacheScheme, colorScheme) &&
        _themeCacheCanvas == canvas) {
      return cached;
    }
    _themeCacheScheme = colorScheme;
    _themeCacheCanvas = canvas;
    return _themeCache = _themePalette(colorScheme, canvas);
  }

  /// 主题色往墨棕色靠一些，放在羊皮纸上更协调
  static Color _parchmentLink(ColorScheme colorScheme) =>
      Color.lerp(colorScheme.primary, const Color(0xFF5C3414), 0.35)!;

  static ReplyPalette _parchmentPalette(ColorScheme colorScheme) =>
      ReplyPalette(
        parchment: true,
        label: const Color(0xFF2B1D10),
        secondaryLabel: const Color(0xB04A3420),
        tertiaryLabel: const Color(0x7A4A3420),
        divider: const Color(0x386B4A26),
        subCard: const Color(0x66FFF8E8),
        fill: const Color(0x1F6B4A26),
        headerBackground: const Color(0xE6EBCE9E),
        link: _parchmentLink(colorScheme),
      );

  static ReplyPalette _themePalette(ColorScheme colorScheme, Color canvas) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final onSurface = colorScheme.onSurface;
    return ReplyPalette(
      parchment: false,
      label: onSurface,
      secondaryLabel: colorScheme.outline,
      tertiaryLabel: colorScheme.outline.withValues(alpha: 0.7),
      divider: onSurface.withValues(alpha: isDark ? 0.12 : 0.08),
      subCard: onSurface.withValues(alpha: isDark ? 0.07 : 0.045),
      fill: onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
      headerBackground: canvas.withValues(alpha: 0.92),
      link: colorScheme.primary,
    );
  }
}

/// 评论区背景：羊皮纸时在内容下方铺一张固定的纸张图（不随列表滚动），
/// 否则不画任何东西，与简介页同底色。
class ReplyBackground extends StatelessWidget {
  const ReplyBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ReplyPalette.of(context).parchment) {
      return child;
    }
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFEBCE9E),
        image: DecorationImage(
          image: AssetImage(Assets.replyParchment),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
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

/// 评论区排版常量
abstract final class ReplyStyle {
  /// 一级评论左右留白（不再包卡片，比原来更宽）
  static const double rootPadding = 14;

  /// 次级评论卡片：iOS 连续曲率圆角
  static const ShapeBorder subCardShape = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  /// 楼中楼面板里单独成卡的次级评论
  static const EdgeInsets subCardMargin = EdgeInsets.fromLTRB(12, 0, 12, 8);

  static const EdgeInsets subCardPadding = EdgeInsets.fromLTRB(12, 10, 12, 10);

  /// 一级评论下方楼中楼卡片的内边距
  static const EdgeInsets threadCardPadding = EdgeInsets.fromLTRB(
    10,
    4,
    10,
    4,
  );

  /// 默认显示的楼中楼条数
  static const int previewCount = 3;

  /// 主评论头像
  static const double avatarSize = 32;

  /// 头像与正文的间距；正文、楼中楼都从这里开始缩进
  static const double avatarGap = 10;

  static const double contentIndent = avatarSize + avatarGap;

  /// 楼中楼头像
  static const double subAvatarSize = 20;

  static const double subAvatarGap = 6;

  static const double subContentIndent = subAvatarSize + subAvatarGap;

  // 除评论正文外，其余文字整体小一号

  static const TextStyle name = TextStyle(
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle subName = TextStyle(
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 11,
    height: 1.25,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 评论正文（一级）
  static const TextStyle content = TextStyle(
    fontSize: 15,
    height: 1.5,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// 评论正文（次级）
  static const TextStyle subContent = TextStyle(
    fontSize: 14,
    height: 1.5,
    letterSpacing: 0.1,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle action = TextStyle(
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w500,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
