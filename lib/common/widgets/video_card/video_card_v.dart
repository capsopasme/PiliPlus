import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/common/widgets/video_popup_menu.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/http/rcmd_feedback.dart';
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/dimension_ext.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

// 视频卡片 - 垂直布局
class VideoCardV extends StatelessWidget {
  final BaseRcmdVideoItemModel videoItem;
  final VoidCallback? onRemove;

  const VideoCardV({
    super.key,
    required this.videoItem,
    this.onRemove,
  });

  Future<void> onPushDetail() async {
    switch (videoItem.goto) {
      case 'bangumi':
        PageUtils.viewPgc(epId: videoItem.param!);
        break;
      case 'av':
        var bvid = videoItem.bvid ?? IdUtils.av2bv(videoItem.aid!);
        var cid = videoItem.cid;
        bool isVertical = false;
        Dimension? dimension;
        if (videoItem case final RcmdVideoItemAppModel item) {
          if (item.uri case final uri?) {
            isVertical = uri.isVerticalFromUri;
          }
          RcmdFeedback.onClick(item);
        }
        if (cid == null) {
          if (await SearchHttp.ab2cWithDimension(aid: videoItem.aid, bvid: bvid)
              case final res?) {
            cid = res.cid;
            dimension = res.dimension;
          }
        }
        if (cid != null) {
          PageUtils.toVideoPage(
            aid: videoItem.aid,
            bvid: bvid,
            cid: cid,
            cover: videoItem.cover,
            title: videoItem.title,
            isVertical: isVertical,
            dimension: dimension,
          );
        }
        break;
      // 动态
      case 'picture':
        try {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        } catch (err) {
          SmartDialog.showToast(err.toString());
        }
        break;
      default:
        if (videoItem.uri?.isNotEmpty == true) {
          PiliScheme.routePushFromUrl(videoItem.uri!);
        }
    }
  }

  /// 卡片圆角
  static const double radius = 18;
  static const BorderRadius _borderRadius = BorderRadius.all(
    Radius.circular(radius),
  );
  static const BorderRadius _coverRadius = BorderRadius.vertical(
    top: Radius.circular(radius),
  );

  /// 卡片正文（封面以下）的高度：文字部分随字号缩放，其余固定
  static double contentExtent(TextScaler textScaler) =>
      textScaler.scale(62) + 58;

  /// 白色卡片 + 很淡的投影。圆角矩形阴影在绘制时走快速路径，开销很小
  static BoxDecoration decoration(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? colorScheme.surfaceContainer
          : colorScheme.surfaceContainerLowest,
      borderRadius: _borderRadius,
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
    );
  }

  String? get _face => switch (videoItem.owner) {
    final RcmdOwner owner => owner.face,
    final Owner owner => owner.face,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    void onLongPress() => imageSaveDialog(
      title: videoItem.title,
      cover: videoItem.cover,
      bvid: videoItem.bvid,
    );
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: decoration(theme.colorScheme),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPushDetail,
          onLongPress: onLongPress,
          onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
          borderRadius: _borderRadius,
          child: Column(
            crossAxisAlignment: .start,
            children: [
              AspectRatio(
                aspectRatio: Style.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, boxConstraints) {
                    final double maxWidth = boxConstraints.maxWidth;
                    final double maxHeight = boxConstraints.maxHeight;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        NetworkImgLayer(
                          src: videoItem.cover,
                          width: maxWidth,
                          height: maxHeight,
                          borderRadius: _coverRadius,
                        ),
                        if (videoItem.duration > 0)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: _DurationBadge(
                              DurationUtils.formatDuration(videoItem.duration),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              content(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget content(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final outline = colorScheme.outline;
    final face = _face;
    final String? badge = videoItem.goto == 'bangumi'
        ? videoItem.pgcBadge
        : videoItem.goto == 'picture'
        ? '动态'
        : videoItem.isFollowed
        ? '已关注'
        : videoItem.rcmdReason;
    return Expanded(
      child: Padding(
        padding: const .fromLTRB(12, 10, 6, 6),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Expanded(
              child: Padding(
                padding: const .only(right: 6),
                child: Text(
                  videoItem.title,
                  maxLines: 2,
                  overflow: .ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.36,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const .only(right: 6, top: 4, bottom: 6),
              child: videoStat(theme, badge),
            ),
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  if (face != null)
                    NetworkImgLayer(
                      src: face,
                      width: 22,
                      height: 22,
                      type: .avatar,
                    )
                  else
                    SizedBox.square(
                      dimension: 22,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      videoItem.owner.name.toString(),
                      maxLines: 1,
                      overflow: .ellipsis,
                      semanticsLabel: 'UP：${videoItem.owner.name}',
                      style: TextStyle(fontSize: 13, color: outline),
                    ),
                  ),
                  if (videoItem.goto == 'av')
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: VideoPopupMenu(
                        iconSize: 18,
                        videoItem: videoItem,
                        onRemove: onRemove,
                      ),
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final shortFormat = DateFormat('M-d');
  static final longFormat = DateFormat('yy-M-d');

  Widget videoStat(ThemeData theme, String? badge) {
    final color = theme.colorScheme.outline;
    return Row(
      children: [
        StatWidget(
          type: .play,
          value: videoItem.stat.view,
          color: color,
          iconSize: 15,
        ),
        if (videoItem.goto != 'picture') ...[
          const SizedBox(width: 12),
          StatWidget(
            type: .danmaku,
            value: videoItem.stat.danmu,
            color: color,
            iconSize: 15,
          ),
        ],
        const SizedBox(width: 8),
        if (badge != null && badge.isNotEmpty)
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
              padding: const .symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: Text(
                badge,
                maxLines: 1,
                overflow: .ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: theme.colorScheme.primary,
                ),
              ),
              ),
            ),
          )
        else if (videoItem is RcmdVideoItemModel) ...[
          const Spacer(),
          Text(
            DateFormatUtils.dateFormat(
              videoItem.pubdate,
              short: shortFormat,
              long: longFormat,
            ),
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );
  }
}

/// 封面右下角的时长：深色半透明胶囊
class _DurationBadge extends StatelessWidget {
  const _DurationBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0x8C000000),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 7, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.3,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 推荐卡片的加载占位，尺寸与 [VideoCardV] 一致
class VideoCardVRcmdSkeleton extends StatelessWidget {
  const VideoCardVRcmdSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final color = colorScheme.onSurface.withValues(alpha: 0.06);
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
    );
    return DecoratedBox(
      decoration: VideoCardV.decoration(colorScheme),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          AspectRatio(
            aspectRatio: Style.aspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: VideoCardV._coverRadius,
              ),
            ),
          ),
          Padding(
            padding: const .fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                bar(double.infinity, 13),
                const SizedBox(height: 7),
                bar(110, 13),
                const SizedBox(height: 14),
                bar(90, 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
