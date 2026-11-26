import 'dart:collection' show Queue;

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
/// - [showAll]：显示原地加载的完整楼中楼，否则显示前 [previewCount] 条预览
///
/// 列表接口每条主评论只附带 2 条楼中楼预览。为了默认显示 3 条，
/// 主评论第一次出现时（[ensurePreview]）请求楼中楼第一页补齐，
/// 这一页同时作为「展开」的首屏缓存，之后展开不再重复请求。
class ReplyThreadState extends ChangeNotifier {
  ReplyThreadState._();

  /// 默认显示的楼中楼条数
  static const int previewCount = 3;

  static List<ReplyInfo> takePreview(List<ReplyInfo> list) =>
      list.length > previewCount ? list.sublist(0, previewCount) : list;

  bool _disposed = false;

  bool collapsed = false;

  bool showAll = false;

  /// 主评论超出行数限制后已展开全文
  bool rootTextExpanded = false;

  final Set<Int64> _expandedText = <Int64>{};

  /// 原地加载到的楼中楼：接口预览 + 多页累积（已去重）
  List<ReplyInfo>? loaded;

  String? _nextOffset;

  bool isEnd = false;

  bool loading = false;

  bool hasError = false;

  /// 已尝试过补齐预览（成功与否都不再重试，避免反复请求）
  bool _previewTried = false;

  /// 补齐预览的请求进行中时用户点了「展开」，请求回来后直接全部显示
  bool _wantShowAll = false;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// 当前应显示的预览：接口预览够 3 条就用接口的，否则用补齐后的第一页
  List<ReplyInfo> previewOf(ReplyInfo root) {
    final base = root.replies;
    final loaded = this.loaded;
    if (base.length >= previewCount || loaded == null) {
      return takePreview(base);
    }
    return takePreview(loaded);
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

  /// 接口预览不足 [previewCount] 条、而实际回复更多时，请求第一页补齐。
  /// 由列表项构建时调用，可重复调用；最多同时进行 2 个请求。
  void ensurePreview(ReplyInfo root) {
    if (_previewTried || loaded != null || loading || _disposed) return;
    final have = root.replies.length;
    if (have >= previewCount || root.count.toInt() <= have) return;
    _previewTried = true;
    _PreviewQueue.run(() async {
      // 排队期间列表已刷新，或用户已经手动展开过
      if (_disposed || loaded != null || loading) return;
      await _fetch(root, silent: true);
      if (_wantShowAll && loaded != null) {
        _wantShowAll = false;
        showAll = true;
      }
      _notify();
    });
  }

  /// 展开剩余回复：先显示缓存，未加载完则继续加载下一页
  Future<void> expandReplies(ReplyInfo root) async {
    if (loading) {
      // 补齐预览的请求还没回来，回来后直接全部显示
      _wantShowAll = true;
      return;
    }
    if (loaded != null && !showAll) {
      showAll = true;
      _notify();
      return;
    }
    if (isEnd) return;

    hasError = false;
    _notify();
    await _fetch(root, silent: false);
    if (!hasError) {
      showAll = true;
    }
    _notify();
  }

  /// 请求楼中楼下一页（第一页时以接口预览打底），结果累积到 [loaded]
  Future<void> _fetch(ReplyInfo root, {required bool silent}) async {
    loading = true;
    if (!silent) _notify();

    final res = await ReplyGrpc.detailList(
      type: root.type.toInt(),
      oid: root.oid.toInt(),
      root: root.id.toInt(),
      rpid: 0,
      mode: _mode,
      offset: _nextOffset,
    );
    loading = false;
    if (_disposed) return;

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
      case Error(:final errMsg):
        if (!silent) {
          hasError = true;
          SmartDialog.showToast(errMsg ?? '加载失败');
        }
      case _:
        if (!silent) hasError = true;
    }
  }
}

/// 补齐预览的请求队列：最多同时 2 个，快速滑动时不会一下子发出一大串请求
abstract final class _PreviewQueue {
  static const int _maxRunning = 2;
  static int _running = 0;
  static final Queue<Future<void> Function()> _pending =
      Queue<Future<void> Function()>();

  static void run(Future<void> Function() task) {
    _pending.add(task);
    _pump();
  }

  static void _pump() {
    while (_running < _maxRunning && _pending.isNotEmpty) {
      final task = _pending.removeFirst();
      _running++;
      task().catchError((_) {}).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }
}
