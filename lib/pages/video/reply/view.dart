import 'package:PiliPlus/common/skeleton/video_reply.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/mini_scaffold.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_floating_header.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/video/reply/controller.dart';
import 'package:PiliPlus/pages/video/reply/vote/reply_vote_item.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_style.dart';
import 'package:PiliPlus/pages/video/reply_reply/view.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class VideoReplyPanel extends StatefulWidget {
  const VideoReplyPanel({
    super.key,
    this.replyLevel = 1,
    required this.heroTag,
    required this.isNested,
  });

  final int replyLevel;
  final String heroTag;
  final bool isNested;

  @override
  State<VideoReplyPanel> createState() => _VideoReplyPanelState();
}

class _VideoReplyPanelState extends State<VideoReplyPanel>
    with AutomaticKeepAliveClientMixin {
  late ColorScheme colorScheme;
  late ReplyPalette palette;
  late VideoReplyController _videoReplyController;

  String get heroTag => widget.heroTag;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _videoReplyController = Get.find<VideoReplyController>(tag: heroTag);
    if (_videoReplyController.loadingState.value is Loading) {
      _videoReplyController.queryData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colorScheme = ColorScheme.of(context);
    palette = ReplyPalette.of(context);
    bottom = MediaQuery.viewPaddingOf(context).bottom;
  }

  late double bottom;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final secondaryLabel = palette.secondaryLabel;
    // 不再提供「发表评论」悬浮按钮（只读）
    return ColoredBox(
      color: palette.background,
      child: refreshIndicator(
        onRefresh: _videoReplyController.onRefresh,
        isClampingScrollPhysics: widget.isNested,
        child: CustomScrollView(
          controller: widget.isNested
              ? null
              : _videoReplyController.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          key: const PageStorageKey(_VideoReplyPanelState),
          slivers: [
            SliverFloatingHeaderWidget(
              // 半透明悬浮排序栏：只是带 alpha 的纯色，不做实时模糊
              backgroundColor: palette.background.withValues(alpha: 0.92),
              child: Padding(
                padding: const .fromLTRB(16, 4, 8, 4),
                child: Obx(() {
                  final sortType = _videoReplyController.sortType.value;
                  return Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Text(
                        sortType.desc,
                        style: ReplyStyle.action.copyWith(
                          fontSize: 13,
                          color: secondaryLabel,
                        ),
                      ),
                      TextButton.icon(
                        style: Style.buttonStyle,
                        onPressed: _videoReplyController.queryBySort,
                        icon: Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        label: Text(
                          sortType.descShort,
                          style: ReplyStyle.action.copyWith(
                            fontSize: 13,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 2)),
            Obx(() => _buildBody(_videoReplyController.loadingState.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(LoadingState<List<ReplyInfo>?> loadingState) {
    switch (loadingState) {
      case Loading():
        return const SliverPrototypeExtentList(
          prototypeItem: VideoReplySkeleton(),
          delegate: SliverSingleChildDelegate(
            count: 5,
            child: VideoReplySkeleton(),
          ),
        );
      case Success(:final response):
        if (response != null && response.isNotEmpty) {
          var count = response.length + 1;
          final voteCard = _videoReplyController.voteCard;
          final hasVote = voteCard != null;
          if (hasVote) {
            count++;
          }
          return SliverList.builder(
            itemBuilder: (context, index) {
              if (hasVote) {
                if (index == 0) {
                  return buildVoteCard(context, colorScheme, voteCard);
                } else {
                  index--;
                }
              }
              if (index == response.length) {
                _videoReplyController.onLoadMore();
                return Container(
                  height: 125,
                  alignment: .center,
                  margin: .only(bottom: bottom),
                  child: Text(
                    _videoReplyController.isEnd ? '没有更多了' : '加载中…',
                    textAlign: .center,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.tertiaryLabel,
                    ),
                  ),
                );
              } else {
                return ReplyItemGrpc(
                  replyItem: response[index],
                  replyLevel: widget.replyLevel,
                  replyReply: replyReply,
                  onReply: _videoReplyController.onReply,
                  onDelete: (item, subIndex) =>
                      _videoReplyController.onRemove(index, item, subIndex),
                  upMid: _videoReplyController.upMid,
                  getTag: () => heroTag,
                  threadStore: _videoReplyController.threadStore,
                  onCheckReply: _videoReplyController.onCheckReply,
                  onToggleTop: (item) => _videoReplyController.onToggleTop(
                    item,
                    index,
                    _videoReplyController.aid,
                    _videoReplyController.videoType.replyType,
                  ),
                );
              }
            },
            itemCount: count,
          );
        }

        final child = HttpError(
          errMsg: '还没有评论',
          onReload: _videoReplyController.onReload,
        );
        if (_videoReplyController.voteCard case final voteCard?) {
          return SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: buildVoteCard(context, colorScheme, voteCard),
              ),
              child,
            ],
          );
        }
        return child;
      case Error(:final errMsg):
        return HttpError(
          errMsg: errMsg,
          onReload: _videoReplyController.onReload,
        );
    }
  }

  // 展示二级回复
  void replyReply(ReplyInfo replyItem, int? id) {
    EasyThrottle.throttle('replyReply', const Duration(milliseconds: 500), () {
      int oid = replyItem.oid.toInt();
      int rpid = replyItem.id.toInt();
      MiniScaffold.of(context).showBottomSheet(
        constraints: const BoxConstraints(),
        (context) => VideoReplyReplyPanel(
          id: id,
          oid: oid,
          rpid: rpid,
          firstFloor: replyItem.replyControl.isNote ? null : replyItem,
          replyType: _videoReplyController.videoType.replyType,
          isVideoDetail: true,
          isNested: widget.isNested,
          upMid: _videoReplyController.upMid,
        ),
      );
    });
  }
}
