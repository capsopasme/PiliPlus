import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo, Mode;
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

/// 一个评论列表里所有楼中楼的展开/折叠状态。
///
/// 列表项滑出屏幕会被回收，状态必须放在列表外面，否则来回滑动会丢失；
/// 由评论列表的 controller 持有，刷新/重载列表时清空。
class ReplyThreadStore {
  final Map<Int64, ReplyThreadState> _states = <Int64, ReplyThreadState>{};

  ReplyThreadState of(ReplyInfo root) =>
      _states[root.id] ??= ReplyThreadState._();

  void clear() {
    for (final state in _states.values) {
      state._disposed = true;
    }
    _states.clear();
  }
}

/// 单条主评论的楼中楼状态（Reddit 式）：
/// - [collapsed]：整串（主评论 + 楼中楼）折叠成一行
/// - [showAll]：显示原地加载的完整楼中楼，否则显示接口自带的 2–3 条预览
class ReplyThreadState extends ChangeNotifier {
  ReplyThreadState._();

  bool _disposed = false;

  bool collapsed = false;

  bool showAll = false;

  /// 主评论超出行数限制后已展开全文
  bool rootTextExpanded = false;

  final Set<Int64> _expandedText = <Int64>{};

  /// 原地加载到的楼中楼：预览 + 多页累积（已去重）
  List<ReplyInfo>? loaded;

  String? _nextOffset;

  bool isEnd = false;

  bool loading = false;

  bool hasError = false;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void toggleCollapsed() {
    collapsed = !collapsed;
    _notify();
  }

  void expandRootText() {
    if (!rootTextExpanded) {
      rootTextExpanded = true;
      _notify();
    }
  }

  bool isTextExpanded(Int64 id) => _expandedText.contains(id);

  void expandText(Int64 id) {
    if (_expandedText.add(id)) {
      _notify();
    }
  }

  /// 收起到预览（已加载的内容保留，再次展开无需重新请求）
  void collapseReplies() {
    if (showAll) {
      showAll = false;
      _notify();
    }
  }

  void removeLoaded(Int64 id) {
    loaded?.removeWhere((item) => item.id == id);
  }

  void notifyChanged() => _notify();

  static Mode get _mode => Pref.reply2SortType == .time
      ? Mode.MAIN_LIST_TIME
      : Mode.MAIN_LIST_HOT;

  /// 展开剩余回复：先显示缓存，未加载完则继续加载下一页
  Future<void> expandReplies(ReplyInfo root) async {
    if (loading) return;
    if (loaded != null && !showAll) {
      showAll = true;
      _notify();
      return;
    }
    if (isEnd) return;

    loading = true;
    hasError = false;
    _notify();

    final res = await ReplyGrpc.detailList(
      type: root.type.toInt(),
      oid: root.oid.toInt(),
      root: root.id.toInt(),
      rpid: 0,
      mode: _mode,
      offset: _nextOffset,
    );
    if (_disposed) return;

    loading = false;
    switch (res) {
      case Success(:final response):
        // 以已显示的预览打底，新加载的接在后面（去重），
        // 展开时已经看到的几条不会跳位置
        final list = loaded ??= List<ReplyInfo>.of(root.replies);
        final ids = <Int64>{for (final item in list) item.id};
        var added = 0;
        for (final item in response.root.replies) {
          if (ids.add(item.id)) {
            list.add(item);
            added++;
          }
        }
        final String? next = response.hasPaginationReply()
            ? response.paginationReply.nextOffset
            : null;
        _nextOffset = next;
        // 没有新内容或拿不到下一页游标时也视为到底，避免重复请求同一页
        isEnd =
            response.cursor.isEnd ||
            added == 0 ||
            next == null ||
            next.isEmpty;
        showAll = true;
      case Error(:final errMsg):
        hasError = true;
        SmartDialog.showToast(errMsg ?? '加载失败');
      case _:
        hasError = true;
    }
    _notify();
  }
}
