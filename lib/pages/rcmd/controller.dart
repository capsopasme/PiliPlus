import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart' show Options;

class RcmdController extends CommonListController {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    queryData();
  }

  /// app 端推荐：上一页最后一张卡片的 idx。官方客户端加载下一页时传它，
  /// 而不是页码；下拉刷新时传 0。
  int? _lastIdx;

  @override
  Future<LoadingState> customGetData() {
    if (!appRcmd) {
      return VideoHttp.rcmdVideoList(freshIdx: page, ps: 20);
    }
    return VideoHttp.rcmdVideoListApp(
      freshIdx: page == 0 ? 0 : (_lastIdx ?? page),
      isRefresh: page == 0,
    ).then((res) {
      if (res case Success(:final response)) {
        for (int i = response.length - 1; i >= 0; i--) {
          final idx = response[i].idx;
          if (idx != null) {
            _lastIdx = idx;
            break;
          }
        }
        _fillFaces(response);
      }
      return res;
    });
  }

  /// UP 主头像缓存（mid → face），整个应用生命周期内复用
  static final Map<int, String> _faceCache = <int, String>{};

  /// app 端推荐卡片不带 UP 主头像：先用缓存补上，缺的合并成一次批量请求，
  /// 回来后刷新列表。每页最多 1 个请求。
  void _fillFaces(List<RcmdVideoItemAppModel> list) {
    final missing = <int>{};
    for (final item in list) {
      final owner = item.owner;
      if (owner is! RcmdOwner || owner.face != null) continue;
      final mid = owner.mid;
      if (mid == null || mid <= 0) continue;
      final cached = _faceCache[mid];
      if (cached != null) {
        owner.face = cached;
      } else {
        missing.add(mid);
      }
    }
    if (missing.isEmpty) return;
    Request()
        .get(
          'https://api.vc.bilibili.com/account/v1/user/cards',
          queryParameters: {'uids': missing.take(50).join(',')},
          options: Options(extra: const {'account': NoAccount()}),
        )
        .then((res) {
          final data = res.data;
          if (data is! Map || data['code'] != 0 || data['data'] is! List) {
            return;
          }
          for (final e in data['data'] as List) {
            if (e is! Map) continue;
            final mid = e['mid'];
            final face = e['face'];
            if (mid is int && face is String && face.isNotEmpty) {
              _faceCache[mid] = face;
            }
          }
          var changed = false;
          for (final item in list) {
            final owner = item.owner;
            if (owner is RcmdOwner && owner.face == null) {
              final face = _faceCache[owner.mid];
              if (face != null) {
                owner.face = face;
                changed = true;
              }
            }
          }
          if (changed && !isClosed) {
            loadingState.refresh();
          }
        });
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData;
  }

  @override
  void handleListResponse(List dataList) {
    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            lastRefreshAt = dataList.length;
          }
          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
  }

  @override
  Future<void> onRefresh() {
    page = 0;
    isEnd = false;
    return queryData();
  }
}
