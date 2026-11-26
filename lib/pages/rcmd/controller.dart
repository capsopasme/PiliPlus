import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

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
      }
      return res;
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
