import 'dart:math';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/report.dart';
import 'package:PiliPlus/common/widgets/emote_tooltip.dart';
import 'package:PiliPlus/common/widgets/gesture/tap_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/image_grid/image_grid_view.dart';
import 'package:PiliPlus/common/widgets/pendant_avatar.dart';
import 'package:PiliPlus/common/widgets/text_more/text_more.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo, ReplyControl, Content, Url, ReplyControl_VoteOption, Emote;
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/reply.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/dynamics/widgets/vote.dart';
import 'package:PiliPlus/pages/member/widget/medal_widget.dart';
import 'package:PiliPlus/pages/save_panel/view.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_style.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_thread.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/context_ext.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/selectable_region_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:PiliPlus/utils/url_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protobuf/protobuf.dart';

part 'package:PiliPlus/common/widgets/context_menu/reply_menu_helper.dart';

/// 评论条目。
///
/// - 不再提供点赞/点踩/回复等写操作按钮，只读展示赞数；
/// - 一级评论不包卡片、左右加宽，评论之间用半透明细线分隔；
///   次级评论（楼中楼）放在半透明圆角卡片里；
/// - [replyLevel] 为 1 且传入 [threadStore] 时，楼中楼采用 Reddit 式：
///   默认显示前 3 条预览，点「展开 N 条回复」原地分页加载全部，
///   点头部空白或左侧留白把整串折叠成一行；
/// - [replyLevel] 为 0（保存评论/我的评论）时不画卡片和分隔线。
class ReplyItemGrpc extends StatelessWidget {
  const ReplyItemGrpc({
    super.key,
    required this.replyItem,
    required this.replyLevel,
    this.replyReply,
    this.needDivider = true,
    this.onReply,
    this.onDelete,
    this.upMid,
    this.showDialogue,
    this.getTag,
    this.onViewImage,
    this.onCheckReply,
    this.onToggleTop,
    this.jumpToDialogue,
    this.threadStore,
  });
  final ReplyInfo replyItem;
  final int replyLevel;
  final Function(ReplyInfo replyItem, int? rpid)? replyReply;
  final bool needDivider;

  /// 已不再展示回复按钮，保留参数以兼容调用方
  final ValueChanged<ReplyInfo>? onReply;
  final Function(ReplyInfo replyItem, int? subIndex)? onDelete;
  final Int64? upMid;
  final VoidCallback? showDialogue;
  final Function? getTag;
  final VoidCallback? onViewImage;
  final ValueChanged<ReplyInfo>? onCheckReply;
  final ValueChanged<ReplyInfo>? onToggleTop;
  final VoidCallback? jumpToDialogue;

  /// 楼中楼原地展开/折叠的状态容器；为 null 时楼中楼只显示预览
  final ReplyThreadStore? threadStore;

  static final _voteRegExp = RegExp(r"^\{vote:\d+?\}$");
  static final _timeRegExp = RegExp(r'^(?:\d+[:：])?\d+[:：]\d+$');
  static bool enableWordRe = Pref.enableWordRe;
  static int? replyLengthLimit = Pref.replyLengthLimit;

  bool get _isFlat => replyLevel == 0;

  /// 楼中楼面板/对话列表里的次级评论单独成卡
  bool get _isSubReplyCard => !_isFlat && replyItem.root != Int64.ZERO;

  static ColorScheme? _linkSchemeBase;
  static Color? _linkSchemeColor;
  static ColorScheme? _linkScheme;

  /// 链接色与主题主色不同（羊皮纸）时，用替换了 primary 的配色渲染正文
  static ColorScheme _schemeWithLink(ColorScheme colorScheme, Color link) {
    if (link == colorScheme.primary) {
      return colorScheme;
    }
    if (identical(_linkSchemeBase, colorScheme) && _linkSchemeColor == link) {
      return _linkScheme!;
    }
    _linkSchemeBase = colorScheme;
    _linkSchemeColor = link;
    return _linkScheme = colorScheme.copyWith(primary: link);
  }

  void _showMorePanel(
    BuildContext context,
    ReplyInfo item,
    VoidCallback onDelete, {
    required bool isSubReply,
  }) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) => morePanel(
        context: context,
        item: item,
        onDelete: onDelete,
        isSubReply: isSubReply,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReplyPalette.of(context);
    final colorScheme = _schemeWithLink(ColorScheme.of(context), palette.link);
    final ReplyThreadState? state = replyLevel == 1
        ? threadStore?.of(replyItem)
        : null;

    void showMore() => _showMorePanel(
      context,
      replyItem,
      () => onDelete?.call(replyItem, null),
      isSubReply: false,
    );

    Widget child;
    if (state != null) {
      child = ListenableBuilder(
        listenable: state,
        builder: (context, _) => state.collapsed
            ? _buildCollapsed(context, palette, state)
            : _buildExpanded(context, colorScheme, palette, state),
      );
    } else {
      child = _buildExpanded(context, colorScheme, palette, null);
    }

    final replyReply = this.replyReply;
    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 没有原地展开能力的场景（如「我的评论」）保持原来的点按行为
      onTap: state == null && replyReply != null
          ? () => replyReply(replyItem, null)
          : null,
      onLongPress: showMore,
      onSecondaryTap: PlatformUtils.isMobile ? null : showMore,
      child: child,
    );

    if (_isFlat) {
      return child;
    }

    if (_isSubReplyCard) {
      return Padding(
        padding: ReplyStyle.subCardMargin,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.subCard,
            borderRadius: ReplyStyle.subCardRadius,
          ),
          child: child,
        ),
      );
    }

    if (state != null) {
      child = AnimatedSize(
        // 列表刷新/删除后同一位置可能换成另一条评论，按状态对象区分，
        // 避免把"换了一条评论"的高度变化也做成动画
        key: ObjectKey(state),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: child,
      );
    }
    if (needDivider) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          ReplyDivider(color: palette.divider),
        ],
      );
    }
    return child;
  }

  /// 只读赞数（已赞时用主题色实心心形）
  static Widget? _buildLike(
    ReplyInfo item,
    ColorScheme colorScheme,
    ReplyPalette palette, {
    bool small = false,
  }) {
    final like = item.like.toInt();
    if (like <= 0) {
      return null;
    }
    final liked = item.replyControl.action == Int64.ONE;
    final double fontSize = small ? 9.5 : 10;
    return Row(
      spacing: 3,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: fontSize + 3.5,
          color: liked ? colorScheme.primary : palette.tertiaryLabel,
        ),
        Text(
          NumUtils.numFormat(like),
          style: TextStyle(
            fontSize: fontSize,
            height: 1.2,
            color: liked ? colorScheme.primary : palette.secondaryLabel,
          ),
        ),
      ],
    );
  }

  static Widget _textAction(
    String text,
    TextStyle style,
    VoidCallback? onTap, {
    IconData? icon,
  }) {
    Widget child = Text(text, style: style);
    if (icon != null) {
      child = Row(
        spacing: 2,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          Icon(icon, size: (style.fontSize ?? 12.5) + 3, color: style.color),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }

  /// 整串折叠后的单行
  Widget _buildCollapsed(
    BuildContext context,
    ReplyPalette palette,
    ReplyThreadState state,
  ) {
    final member = replyItem.member;
    final count = replyItem.count.toInt();
    final snippet = replyItem.content.message.replaceAll('\n', ' ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        feedBack();
        state.toggleCollapsed();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ReplyStyle.rootPadding,
          10,
          ReplyStyle.rootPadding,
          10,
        ),
        child: Row(
          children: [
            NetworkImgLayer(
              src: member.face,
              width: 22,
              height: 22,
              type: .avatar,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ReplyStyle.subName.copyWith(color: palette.label),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                snippet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ReplyStyle.meta.copyWith(
                  fontSize: 11.5,
                  color: palette.secondaryLabel,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$count 条回复',
                style: ReplyStyle.meta.copyWith(color: palette.tertiaryLabel),
              ),
            ],
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: palette.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(
    BuildContext context,
    ColorScheme colorScheme,
    ReplyPalette palette,
    ReplyThreadState? state,
  ) {
    final replyControl = replyItem.replyControl;
    final footer = _buildFooter(context, colorScheme, palette, replyControl);
    final hasThread = replyLevel == 1 && replyItem.count > Int64.ZERO;
    final replyReply = this.replyReply;
    if (hasThread && state != null) {
      // 预览不足 3 条时补齐（只请求一次，结果缓存在状态里）
      state.ensurePreview(replyItem);
    }

    VoidCallback? onShowMore;
    if (replyLevel == 1) {
      if (state != null) {
        onShowMore = state.expandRootText;
      } else if (replyReply != null) {
        onShowMore = () => replyReply(replyItem, null);
      }
    }

    return Padding(
      padding: _isFlat
          ? const EdgeInsets.fromLTRB(12, 12, 12, 10)
          : _isSubReplyCard
          ? ReplyStyle.subCardPadding
          : const EdgeInsets.fromLTRB(
              ReplyStyle.rootPadding,
              12,
              ReplyStyle.rootPadding,
              12,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, colorScheme, palette, state),
          Padding(
            padding: const EdgeInsets.only(
              left: ReplyStyle.contentIndent,
              top: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyControl.hasVoteOption())
                  _buildVoteOption(
                    colorScheme,
                    palette,
                    replyControl.voteOption,
                  ),
                TextMore.rich(
                  primary: colorScheme.primary,
                  style: ReplyStyle.content.copyWith(color: palette.label),
                  maxLines:
                      replyLevel == 1 && !(state?.rootTextExpanded ?? false)
                      ? replyLengthLimit
                      : null,
                  onShowMore: onShowMore,
                  TextSpan(
                    children: [
                      if (replyControl.isUpTop) ...[
                        const WidgetSpan(
                          alignment: .middle,
                          child: PBadge(
                            text: 'TOP',
                            size: .small,
                            isStack: false,
                            type: .line_primary,
                            fontSize: 9,
                            textScaleFactor: 1,
                          ),
                        ),
                        const TextSpan(text: ' '),
                      ],
                      _buildMessage(
                        context,
                        colorScheme,
                        replyControl.showTranslation
                            ? replyItem.translatedContent
                            : replyItem.content,
                        replyControl,
                      ),
                    ],
                  ),
                ),
                if (replyItem.content.pictures.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ImageGridView(
                      picArr: replyItem.content.pictures
                          .map(
                            (item) => ImageModel(
                              width: item.imgWidth,
                              height: item.imgHeight,
                              url: item.imgSrc,
                            ),
                          )
                          .toList(),
                      onViewImage: onViewImage,
                    ),
                  ),
                ?footer,
              ],
            ),
          ),
          if (hasThread) _buildThread(context, colorScheme, palette, state),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    ReplyPalette palette,
    ReplyThreadState? state,
  ) {
    final member = replyItem.member;
    final replyControl = replyItem.replyControl;
    final isVip = member.vipStatus > 0 && member.vipType == 2;

    void toMember() {
      feedBack();
      Get.toNamed('/member?mid=${replyItem.mid}');
    }

    final time = replyLevel == 0
        ? DateFormatUtils.format(
            replyItem.ctime.toInt(),
            format: DateFormatUtils.longFormatDs,
          )
        : DateFormatUtils.dateFormat(replyItem.ctime.toInt());
    final meta = replyControl.hasLocation()
        ? '$time · ${replyControl.location}'
        : time;
    final like = _buildLike(replyItem, colorScheme, palette);

    Widget header = Row(
      children: [
        GestureDetector(
          onTap: toMember,
          child: PendantAvatar(
            member.face,
            size: ReplyStyle.avatarSize,
            badgeSize: 11,
            vipStatus: member.vipStatus.toInt(),
            officialType: member.officialVerifyType.toInt(),
            pendantImage: member.hasGarbPendantImage()
                ? member.garbPendantImage
                : null,
          ),
        ),
        const SizedBox(width: ReplyStyle.avatarGap),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 5,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: toMember,
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ReplyStyle.name.copyWith(
                          color: isVip ? colorScheme.vipColor : palette.label,
                        ),
                      ),
                    ),
                  ),
                  BiliUtils.levelPicture(
                    member.level.toInt(),
                    isSeniorMember: member.isSeniorMember == 1,
                    height: 9,
                  ),
                  if (replyItem.mid == upMid)
                    const PBadge(
                      text: 'UP',
                      size: .small,
                      isStack: false,
                      fontSize: 9,
                    )
                  else if (GlobalData().showMedal &&
                      member.hasFansMedalLevel())
                    MedalWidget(
                      medalName: member.fansMedalName,
                      level: member.fansMedalLevel.toInt(),
                      backgroundColor: DmUtils.decimalToColor(
                        member.fansMedalColor.toInt(),
                      ),
                      nameColor: DmUtils.decimalToColor(
                        member.fansMedalColorName.toInt(),
                      ),
                      padding: const .symmetric(horizontal: 6, vertical: 1.5),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ReplyStyle.meta.copyWith(color: palette.secondaryLabel),
              ),
            ],
          ),
        ),
        if (like != null) ...[const SizedBox(width: 8), like],
      ],
    );
    if (state != null) {
      // 点头部空白处整串折叠（头像/昵称仍进入空间）
      header = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          feedBack();
          state.toggleCollapsed();
        },
        child: header,
      );
    }
    return header;
  }

  Widget _buildVoteOption(
    ColorScheme colorScheme,
    ReplyPalette palette,
    ReplyControl_VoteOption voteOption,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            switch (voteOption.labelKind) {
              .RED => TextSpan(
                text: '红方  ',
                style: TextStyle(color: colorScheme.vipColor),
              ),
              .BLUE => TextSpan(
                text: '蓝方  ',
                style: TextStyle(color: colorScheme.blue),
              ),
              _ => TextSpan(
                text: '投票  ',
                style: TextStyle(color: palette.tertiaryLabel),
              ),
            },
            TextSpan(text: voteOption.desc),
          ],
        ),
        style: ReplyStyle.meta.copyWith(
          fontSize: 12,
          height: 1.5,
          color: palette.secondaryLabel,
        ),
      ),
    );
  }

  /// 翻译 / 卡片标签 / 查看对话（只读相关的操作）
  Widget? _buildFooter(
    BuildContext context,
    ColorScheme colorScheme,
    ReplyPalette palette,
    ReplyControl replyControl,
  ) {
    final textStyle = ReplyStyle.action.copyWith(color: palette.secondaryLabel);
    final children = <Widget>[];

    if (replyControl.translationSwitch ==
        .TRANSLATION_SWITCH_SHOW_TRANSLATION) {
      children.add(
        _buildTranslateBtn(context, colorScheme, replyControl, textStyle),
      );
    } else if (replyControl.cardLabels.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            replyControl.cardLabels.map((e) => e.textContent).join('  '),
            style: textStyle.copyWith(color: colorScheme.secondary),
          ),
        ),
      );
    }

    final linkStyle = textStyle.copyWith(color: colorScheme.primary);
    if (replyLevel == 2 && needDivider && replyItem.id != replyItem.dialog) {
      children.add(_textAction('查看对话', linkStyle, showDialogue));
    } else if (replyLevel == 3 && replyItem.parent != replyItem.root) {
      children.add(_textAction('跳转回复', linkStyle, jumpToDialogue));
    }

    if (children.isEmpty) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildTranslateBtn(
    BuildContext context,
    ColorScheme colorScheme,
    ReplyControl replyControl,
    TextStyle textStyle,
  ) {
    late bool isProcessing = false;
    final color = replyControl.showTranslation
        ? colorScheme.primary
        : textStyle.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (replyControl.showTranslation) {
          replyControl.showTranslation = false;
          (context as Element).markNeedsBuild();
        } else {
          if (isProcessing) {
            return;
          }
          if (replyItem.hasTranslatedContent()) {
            replyControl.showTranslation = true;
            (context as Element).markNeedsBuild();
            return;
          }
          isProcessing = true;
          final res = await ReplyGrpc.translateReply(
            type: replyItem.type,
            oid: replyItem.oid,
            rpid: replyItem.id,
          );
          if (res case Success(:final response)) {
            final item = response.translatedReplies[replyItem.id];
            if (item != null && item.hasTranslatedContent()) {
              replyControl.showTranslation = true;
              replyItem.translatedContent = item.translatedContent;
              if (context.mounted) {
                (context as Element).markNeedsBuild();
              }
            } else {
              SmartDialog.showToast('翻译结果为空');
            }
          } else if (res case Error(:final errMsg)) {
            SmartDialog.showToast('翻译失败: $errMsg');
          }
          isProcessing = false;
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          spacing: 3,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate, size: 13, color: color),
            Text(
              replyControl.showTranslation ? '原文' : '翻译',
              style: textStyle.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  /// 楼中楼（Reddit 式）：放在与正文对齐的圆角卡片里，默认显示前
  /// [ReplyThreadState.previewCount] 条。
  ///
  /// 列表接口每条主评论只附带 2 条预览，不足的部分由 [ReplyThreadState.ensurePreview]
  /// 请求楼中楼第一页补齐；这一页同时缓存下来，之后点「展开」直接显示，不再重复请求。
  Widget _buildThread(
    BuildContext context,
    ColorScheme colorScheme,
    ReplyPalette palette,
    ReplyThreadState? state,
  ) {
    final List<ReplyInfo> preview =
        state?.previewOf(replyItem) ??
        ReplyThreadState.takePreview(replyItem.replies);
    final List<ReplyInfo>? loaded = state?.loaded;
    final bool showAll = state != null && state.showAll && loaded != null;
    final List<ReplyInfo> items = showAll ? loaded : preview;
    final int total = replyItem.count.toInt();
    final linkStyle = ReplyStyle.action.copyWith(color: palette.link);
    final mutedStyle = ReplyStyle.action.copyWith(
      color: palette.secondaryLabel,
    );
    final upPrefix = replyItem.replyControl.upReply ? 'UP主等人 · ' : '';

    Widget? footer;
    if (state == null) {
      if (total > items.length) {
        final replyReply = this.replyReply;
        footer = _textAction(
          '$upPrefix共 $total 条回复',
          linkStyle,
          replyReply == null ? null : () => replyReply(replyItem, null),
          icon: Icons.chevron_right_rounded,
        );
      }
    } else if (state.loading && showAll) {
      footer = _textAction('加载中…', mutedStyle, null);
    } else if (showAll ? !state.isEnd : total > items.length) {
      final remaining = total - items.length;
      footer = _textAction(
        state.hasError && showAll
            ? '加载失败，点击重试'
            : showAll
            ? '展开更多回复'
            : remaining > 0
            ? '$upPrefix共 $total 条回复'
            : '展开更多回复',
        linkStyle,
        () => state.expandReplies(replyItem),
        icon: showAll ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
      );
    } else if (showAll && items.length > preview.length) {
      footer = _textAction(
        '收起',
        mutedStyle,
        state.collapseReplies,
        icon: Icons.expand_less_rounded,
      );
    }

    if (items.isEmpty && footer == null) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(_subDivider(context, palette));
      }
      children.add(
        _buildSubReply(context, colorScheme, palette, items[i], state),
      );
    }
    if (footer != null) {
      if (children.isNotEmpty) {
        children.add(_subDivider(context, palette));
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(
            left: ReplyStyle.subContentIndent,
            top: 2,
            bottom: 2,
          ),
          child: footer,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: ReplyStyle.contentIndent),
            child: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.subCard,
                  borderRadius: ReplyStyle.subCardRadius,
                ),
                child: Padding(
                  padding: ReplyStyle.threadCardPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
          // 卡片左侧（主评论头像正下方）的留白：点按整串折叠
          if (state != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: ReplyStyle.contentIndent - 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  feedBack();
                  state.toggleCollapsed();
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 楼中楼卡片内的细线（1 个物理像素，左侧与回复正文对齐）
  static Widget _subDivider(BuildContext context, ReplyPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(left: ReplyStyle.subContentIndent),
      child: SizedBox(
        height: 1 / MediaQuery.devicePixelRatioOf(context),
        width: double.infinity,
        child: ColoredBox(color: palette.subDivider),
      ),
    );
  }

  Widget _buildSubReply(
    BuildContext context,
    ColorScheme colorScheme,
    ReplyPalette palette,
    ReplyInfo child,
    ReplyThreadState? state,
  ) {
    final member = child.member;
    final isVip = member.vipStatus > 0 && member.vipType == 2;
    final like = _buildLike(child, colorScheme, palette, small: true);
    final replyReply = this.replyReply;

    void toMember() {
      feedBack();
      Get.toNamed('/member?mid=${child.mid}');
    }

    void showMore() => _showMorePanel(
      context,
      child,
      () => _onDeleteSub(child, state),
      isSubReply: true,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 打开完整楼中楼面板并定位到这条（可查看对话、切换排序）
      onTap: replyReply == null
          ? null
          : () => replyReply(replyItem, child.id.toInt()),
      onLongPress: showMore,
      onSecondaryTap: PlatformUtils.isMobile ? null : showMore,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: toMember,
                  child: NetworkImgLayer(
                    src: member.face,
                    width: ReplyStyle.subAvatarSize,
                    height: ReplyStyle.subAvatarSize,
                    type: .avatar,
                  ),
                ),
                const SizedBox(width: ReplyStyle.subAvatarGap),
                Flexible(
                  child: GestureDetector(
                    onTap: toMember,
                    child: Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ReplyStyle.subName.copyWith(
                        color: isVip ? colorScheme.vipColor : palette.label,
                      ),
                    ),
                  ),
                ),
                if (child.mid == upMid) ...[
                  const SizedBox(width: 4),
                  const PBadge(
                    text: 'UP',
                    size: .small,
                    isStack: false,
                    fontSize: 9,
                    textScaleFactor: 1,
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  DateFormatUtils.dateFormat(child.ctime.toInt()),
                  style: ReplyStyle.meta.copyWith(
                    color: palette.tertiaryLabel,
                  ),
                ),
                const Spacer(),
                ?like,
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: ReplyStyle.subContentIndent,
                top: 2,
              ),
              child: TextMore.rich(
                primary: colorScheme.primary,
                style: ReplyStyle.subContent.copyWith(color: palette.label),
                maxLines: state != null && state.isTextExpanded(child.id)
                    ? null
                    : replyLengthLimit,
                onShowMore: state == null
                    ? null
                    : () => state.expandText(child.id),
                TextSpan(
                  children: [
                    _buildMessage(
                      context,
                      colorScheme,
                      child.content,
                      child.replyControl,
                    ),
                  ],
                ),
              ),
            ),
            if (child.content.pictures.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(
                  left: ReplyStyle.subContentIndent,
                  top: 4,
                ),
                child: ImageGridView(
                  picArr: child.content.pictures
                      .map(
                        (item) => ImageModel(
                          width: item.imgWidth,
                          height: item.imgHeight,
                          url: item.imgSrc,
                        ),
                      )
                      .toList(),
                  onViewImage: onViewImage,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onDeleteSub(ReplyInfo child, ReplyThreadState? state) {
    state?.removeLoaded(child.id);
    final index = replyItem.replies.indexWhere((item) => item.id == child.id);
    if (index != -1) {
      // 由列表 controller 从预览中移除并刷新
      onDelete?.call(replyItem, index);
    } else {
      replyItem.count -= Int64.ONE;
    }
    state?.notifyChanged();
  }

  static const _basePatterns = [
    r'(?:\d+[:：])?\d+[:：]\d+',
    r'\{vote:\d+?\}',
  ];

  /// 不含表情/话题/@/链接关键字的评论（占大多数）共用一个预编译的正则
  static final RegExp _basePattern = RegExp(
    [..._basePatterns, Constants.urlRegex.pattern].join('|'),
  );

  /// 含关键字的评论按 Content 缓存编译好的正则，来回滑动重建时不再重新编译
  static final Expando<RegExp> _patternCache = Expando<RegExp>();

  static RegExp _patternFor(Content content) {
    if (content.emotes.isEmpty &&
        content.topics.isEmpty &&
        content.atNameToMid.isEmpty &&
        content.urls.isEmpty) {
      return _basePattern;
    }
    return _patternCache[content] ??= RegExp(
      [
        ...content.emotes.keys.map(RegExp.escape),
        ...content.topics.keys.map((e) => RegExp.escape('#$e#')),
        ...content.atNameToMid.keys.map((e) => RegExp.escape('@$e')),
        ...content.urls.keys.map(RegExp.escape),
        ..._basePatterns,
        Constants.urlRegex.pattern,
      ].join('|'),
    );
  }

  InlineSpan _buildMessage(
    BuildContext context,
    ColorScheme colorScheme,
    Content content,
    ReplyControl replyControl,
  ) {
    final List<InlineSpan> spanChildren = <InlineSpan>[];
    bool hasNote = false;

    final RegExp pattern = _patternFor(content);

    late List<String> matchedUrls = [];

    void addPlainTextSpan(str) {
      spanChildren.add(TextSpan(text: str));
    }

    void addUrl(String matchStr, Url url, {bool addPlainText = false}) {
      if (url.extra.isWordSearch && !enableWordRe) {
        if (addPlainText) {
          addPlainTextSpan(matchStr);
        }
        return;
      }
      final isCv = url.clickReport.startsWith('{"cvid');
      if (isCv) {
        hasNote = true;
      }
      final children = [
        if (!isCv && url.hasPrefixIcon())
          WidgetSpan(
            child: CachedNetworkImage(
              height: 19,
              memCacheHeight: 19.cacheSize(context),
              color: colorScheme.primary,
              imageUrl: ImageUtils.thumbnailUrl(url.prefixIcon),
              placeholder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        TextSpan(
          text: isCv ? '[笔记] ' : url.title,
          style: TextStyle(color: colorScheme.primary),
          recognizer: NoDeadlineTapGestureRecognizer()
            ..onTap = () {
              if (url.appUrlSchema.isEmpty) {
                if (RegExp(
                  r'^(av|bv)',
                  caseSensitive: false,
                ).hasMatch(matchStr)) {
                  UrlUtils.matchUrlPush(matchStr, '');
                } else {
                  RegExpMatch? match = RegExp(
                    r'^cv(\d+)$|/read/cv(\d+)|note-app/view\?cvid=(\d+)',
                    caseSensitive: false,
                  ).firstMatch(matchStr);
                  String? cvid =
                      match?.group(1) ?? match?.group(2) ?? match?.group(3);
                  if (cvid != null) {
                    Get.toNamed(
                      '/articlePage',
                      parameters: {
                        'id': cvid,
                        'type': 'read',
                      },
                    );
                    return;
                  }
                  PageUtils.handleWebview(matchStr);
                }
              } else {
                if (url.extra.isWordSearch) {
                  Get.toNamed(
                    '/searchResult',
                    parameters: {'keyword': url.title},
                  );
                } else {
                  PageUtils.handleWebview(matchStr);
                }
              }
            },
        ),
      ];
      if (isCv) {
        spanChildren.insertAll(0, children);
      } else {
        spanChildren.addAll(children);
      }
    }

    // 分割文本并处理每个部分
    content.message.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        String matchStr = match[0]!;
        late final name = matchStr.substring(1);
        late final topic = matchStr.substring1;
        if (content.emotes.containsKey(matchStr)) {
          // 处理表情
          final emote = content.emotes[matchStr]!;
          final size = emote.size.toInt() * 20.0;
          final url = emote.hasWebpUrl()
              ? emote.webpUrl
              : emote.hasGifUrl()
              ? emote.gifUrl
              : emote.url;
          spanChildren.add(
            WidgetSpan(
              child: emoteTooltipBuilder(
                url: url,
                emote: matchStr,
                triggerMode: .tap,
                jumpUrl: emote.hasJumpUrl() ? emote.jumpUrl : null,
                colorScheme: colorScheme,
                child: NetworkImgLayer(
                  src: url,
                  type: .emote,
                  width: size,
                  height: size,
                ),
              ),
            ),
          );
        } else if (matchStr.startsWith("@") &&
            content.atNameToMid.containsKey(name)) {
          // 处理@用户
          spanChildren.add(
            TextSpan(
              text: matchStr,
              style: TextStyle(color: colorScheme.primary),
              recognizer: NoDeadlineTapGestureRecognizer()
                ..onTap = () =>
                    Get.toNamed('/member?mid=${content.atNameToMid[name]}'),
            ),
          );
        } else if (_voteRegExp.hasMatch(matchStr)) {
          spanChildren.add(
            TextSpan(
              text: '投票: ${content.vote.title}',
              style: TextStyle(color: colorScheme.primary),
              recognizer: NoDeadlineTapGestureRecognizer()
                ..onTap = () =>
                    showVoteDialog(context, content.vote.id.toInt()),
            ),
          );
        } else if (_timeRegExp.hasMatch(matchStr)) {
          matchStr = matchStr.replaceAll('：', ':');
          bool isValid = false;
          try {
            final ctr = Get.find<VideoDetailController>(
              tag: getTag?.call() ?? Get.arguments['heroTag'],
            );
            isValid =
                DurationUtils.parseDuration(matchStr) * 1000 <=
                ctr.data.timeLength!;
          } catch (e) {
            if (kDebugMode) debugPrint('failed to validate: $e');
          }
          spanChildren.add(
            TextSpan(
              text: isValid ? ' $matchStr ' : matchStr,
              style: isValid ? TextStyle(color: colorScheme.primary) : null,
              recognizer: isValid
                  ? (NoDeadlineTapGestureRecognizer()
                      ..onTap = () {
                        // 跳转到指定位置
                        try {
                          SmartDialog.showToast('跳转至：$matchStr');
                          Get.find<VideoDetailController>(
                            tag: Get.arguments['heroTag'],
                          ).plPlayerController.seekTo(
                            Duration(
                              seconds: DurationUtils.parseDuration(matchStr),
                            ),
                            isSeek: false,
                          );
                        } catch (e) {
                          SmartDialog.showToast('跳转失败: $e');
                        }
                      })
                  : null,
            ),
          );
        } else {
          final url = content.urls[matchStr];
          if (url != null && !matchedUrls.contains(matchStr)) {
            addUrl(matchStr, url, addPlainText: true);
            // 只显示一次
            matchedUrls.add(matchStr);
          } else if (matchStr.length > 1 && content.topics[topic] != null) {
            spanChildren.add(
              TextSpan(
                text: matchStr,
                style: TextStyle(color: colorScheme.primary),
                recognizer: NoDeadlineTapGestureRecognizer()
                  ..onTap = () {
                    Get.toNamed(
                      '/searchResult',
                      parameters: {'keyword': topic},
                    );
                  },
              ),
            );
          } else if (Constants.urlRegex.hasMatch(matchStr)) {
            spanChildren.add(
              TextSpan(
                text: matchStr,
                style: TextStyle(color: colorScheme.primary),
                recognizer: NoDeadlineTapGestureRecognizer()
                  ..onTap = () => PageUtils.handleWebview(matchStr),
              ),
            );
          } else {
            addPlainTextSpan(matchStr);
          }
        }
        return '';
      },
      onNonMatch: (String nonMatchStr) {
        addPlainTextSpan(nonMatchStr);
        return nonMatchStr;
      },
    );

    // if (urlKeys.isNotEmpty) {
    //   List<String> unmatchedItems = urlKeys
    //       .where((url) => !matchedUrls.contains(url))
    //       .toList();
    //   if (unmatchedItems.isNotEmpty) {
    //     for (final patternStr in unmatchedItems) {
    //       addUrl(patternStr, content.urls[patternStr]!);
    //     }
    //   }
    // }

    if (!hasNote && replyControl.isNote && replyControl.isNoteV2) {
      final Color color;
      NoDeadlineTapGestureRecognizer? recognizer;

      final hasClickUrl = content.richText.note.hasClickUrl();
      if (hasClickUrl || content.richText.opus.hasOpusId()) {
        color = colorScheme.primary;
        recognizer = NoDeadlineTapGestureRecognizer()
          ..onTap = () => hasClickUrl
              ? PiliScheme.routePushFromUrl(content.richText.note.clickUrl)
              : Get.toNamed(
                  '/articlePage',
                  parameters: {
                    'id': content.richText.opus.opusId.toString(),
                    'type': 'opus',
                  },
                );
      } else {
        color = colorScheme.secondary;
      }
      spanChildren.insert(
        0,
        TextSpan(
          text: '[笔记] ',
          style: TextStyle(color: color),
          recognizer: recognizer,
        ),
      );
    }

    return TextSpan(children: spanChildren);
  }

  Widget morePanel({
    required BuildContext context,
    required ReplyInfo item,
    required VoidCallback onDelete,
    required bool isSubReply,
  }) {
    late String message = item.content.message;
    final ownerMid = Int64(Accounts.main.mid);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorColor = colorScheme.error;
    final style = theme.textTheme.titleSmall!;

    return Padding(
      padding: .only(
        bottom: MediaQuery.viewPaddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: Get.back,
            borderRadius: Style.bottomSheetRadius,
            child: SizedBox(
              height: 35,
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ),
          if (kDebugMode && GStorage.reply != null) ...[
            ListTile(
              onTap: () {
                Get.back();
                GStorage.reply!.put(
                  item.id.toString(),
                  (item.deepCopy()
                        ..unknownFields.clear()
                        ..replies.clear()
                        ..clearTrackInfo())
                      .writeToBuffer(),
                );
              },
              title: Text(
                'save to local',
                style: style.copyWith(color: colorScheme.primary),
              ),
            ),
            ListTile(
              onTap: () {
                Get.back();
                onDelete();
                GStorage.reply!.delete(item.id.toString());
              },
              title: Text(
                'remove from local',
                style: style.copyWith(color: colorScheme.primary),
              ),
            ),
            ListTile(
              onTap: () {
                Get.back();
                final oid = item.oid.toInt();
                final data =
                    (item.deepCopy()
                          ..unknownFields.clear()
                          ..replies.clear()
                          ..clearTrackInfo())
                        .writeToBuffer();
                GStorage.reply!.putAll({
                  for (var i = oid; i < oid + 1000; i++) i.toString(): data,
                });
              },
              title: Text(
                'save to local (x1000)',
                style: style.copyWith(color: colorScheme.primary),
              ),
            ),
          ],
          if (ownerMid == upMid || ownerMid == item.member.mid)
            ListTile(
              onTap: () async {
                Get.back();
                bool? isDelete = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    final colorScheme = ColorScheme.of(context);
                    return AlertDialog(
                      title: const Text('删除评论'),
                      content: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '确定删除这条评论吗？\n\n'),
                            if (ownerMid != item.member.mid.toInt()) ...[
                              TextSpan(
                                text: '@${item.member.name}',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                ),
                              ),
                              const TextSpan(text: ':\n'),
                            ],
                            TextSpan(text: message),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Get.back(result: false),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.back(result: true),
                          child: const Text('确定'),
                        ),
                      ],
                    );
                  },
                );
                if (isDelete == null || !isDelete) {
                  return;
                }
                SmartDialog.showLoading(msg: '删除中...');
                final res = await VideoHttp.replyDel(
                  type: item.type.toInt(),
                  oid: item.oid.toInt(),
                  rpid: item.id.toInt(),
                );
                SmartDialog.dismiss();
                if (res.isSuccess) {
                  SmartDialog.showToast('删除成功');
                  onDelete();
                } else {
                  SmartDialog.showToast('删除失败, $res');
                }
              },
              minLeadingWidth: 0,
              leading: Icon(Icons.delete_outlined, color: errorColor, size: 19),
              title: Text('删除', style: style.copyWith(color: errorColor)),
            ),
          if (ownerMid == Int64.ZERO)
            ListTile(
              onTap: () {
                Get.back();
                Pref.setBlackMid(item.mid.toInt());
                onDelete();
                SmartDialog.showToast('屏蔽成功');
                return;
              },
              minLeadingWidth: 0,
              leading: Icon(Icons.error_outline, color: errorColor, size: 19),
              title: Text(
                '屏蔽',
                style: TextStyle(fontSize: 14, color: errorColor),
              ),
            )
          else
            ListTile(
              onTap: () {
                Get.back();

                final oid = item.oid;
                final rpid = item.id;

                autoWrapReportDialog(
                  context,
                  onRemove: onDelete,
                  mid: () => item.mid.toInt(),
                  ReportOptions.commentReport,
                  withContent: ReportOptions.withContentReply,
                  contentRequired: ReportOptions.contentRequiredReply,
                  reportUrl:
                      'https://www.bilibili.com/h5/comment/report?oid=$oid&pageType=${item.type}&rpid=$rpid&platform=android&build=8430300&${ThemeUtils.themeUrl(colorScheme.isDark)}',
                  (reasonType, reasonDesc, banUid) async {
                    final res = await ReplyHttp.report(
                      rpid: rpid,
                      oid: oid,
                      reasonType: reasonType,
                      reasonDesc: reasonDesc,
                      banUid: banUid,
                    );
                    if (res.isSuccess) {
                      onDelete();
                    }
                    return res;
                  },
                );
              },
              minLeadingWidth: 0,
              leading: Icon(Icons.error_outline, color: errorColor, size: 19),
              title: Text('举报', style: style.copyWith(color: errorColor)),
            ),
          if (replyLevel == 1 && !isSubReply && ownerMid == upMid)
            ListTile(
              onTap: () {
                Get.back();
                onToggleTop?.call(item);
              },
              minLeadingWidth: 0,
              leading: const Icon(Icons.vertical_align_top, size: 19),
              title: Text(
                '${replyItem.replyControl.isUpTop ? '取消' : ''}置顶',
                style: style,
              ),
            ),
          ListTile(
            onTap: () {
              Get.back();
              Utils.copyText(message);
            },
            minLeadingWidth: 0,
            leading: const Icon(Icons.copy_all_outlined, size: 19),
            title: Text('复制全部', style: style),
          ),
          ListTile(
            onTap: () {
              Get.back();
              showReplyCopyDialog(context, message, item.content.emotes);
            },
            minLeadingWidth: 0,
            leading: const Icon(Icons.copy_outlined, size: 19),
            title: Text('自由复制', style: style),
          ),
          ListTile(
            onTap: () {
              Get.back();
              SavePanel.toSavePanel(upMid: upMid, item: item);
            },
            minLeadingWidth: 0,
            leading: const Icon(Icons.save_alt, size: 19),
            title: Text('保存评论', style: style),
          ),
          if (kDebugMode || item.mid == ownerMid)
            ListTile(
              onTap: () {
                Get.back();
                onCheckReply?.call(item);
              },
              minLeadingWidth: 0,
              leading: const Icon(CustomIcons.shield_reply, size: 19),
              title: Text('检查评论', style: style),
            ),
        ],
      ),
    );
  }
}
