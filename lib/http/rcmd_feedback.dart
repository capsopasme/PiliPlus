import 'dart:math' show Random, max;

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/app_sign.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:dio/dio.dart';

/// 把「从首页推荐点开了哪条、看了多久」回传给 app 端推荐系统。
///
/// 官方客户端点开推荐卡片时会用卡片的 `track_id` 请求 app 端视频详情
/// （`app.bilibili.com/x/v2/view`，from=7 表示来自首页推荐），播放过程中再上报
/// 移动端心跳（`x/report/heartbeat/mobile`，带同一个来源）。推荐系统靠这两样
/// 把「推给你 → 你点了 → 看了多久」串起来，下一次推荐才会往这个方向调。
///
/// 本应用的详情、取流、心跳走的都是网页端接口：观看历史会记录，
/// 但推荐系统收不到「这条推荐被点开并看完」的反馈，首页推荐就几乎不变。
///
/// 两个请求都是发出即忘，失败不提示；每打开一个视频只多 1 个详情请求，
/// 心跳只在暂停/播完/退出时补发，不增加播放中的定时请求。
abstract final class RcmdFeedback {
  static final bool enabled = Pref.appRcmd && Pref.rcmdFeedback;

  static _Session? _session;

  static final Random _random = Random();

  static Map<String, String> get _headers => {
    'buvid': LoginHttp.buvid,
    'env': 'prod',
    'app-key': 'android_i',
    'User-Agent': Constants.userAgentAppIntl,
    'x-bili-trace-id': Constants.traceId,
  };

  static Map<String, Object> get _identity => {
    'build': Constants.buildAppIntl,
    'c_locale': 'zh_CN',
    's_locale': 'zh_CN',
    'channel': 'master',
    'mobi_app': 'android_i',
    'platform': 'android',
  };

  static Account? get _account {
    final account = Accounts.get(AccountType.recommend);
    final accessKey = account.accessKey;
    if (!account.isLogin || accessKey == null || accessKey.isEmpty) {
      return null;
    }
    return account;
  }

  /// 点开首页推荐卡片时调用
  static void onClick(RcmdVideoItemAppModel item) {
    if (!enabled || item.goto != 'av') return;
    final aid = item.aid;
    final account = _account;
    if (aid == null || account == null) return;

    _session = _Session(
      aid: aid,
      trackId: item.trackId,
      startTs: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      session: List.generate(
        32,
        (_) => _random.nextInt(16).toRadixString(16),
      ).join(),
    );

    Request().get(
      '${HttpString.appBaseUrl}/x/v2/view',
      queryParameters: {
        ..._identity,
        'aid': aid,
        'autoplay': 0,
        'from': 7,
        'from_spmid': 'tm.recommend.0.0',
        'spmid': 'main.ugc-video-detail.0.0',
        'plat': 0,
        'fnval': 976,
        'fnver': 0,
        'fourk': 1,
        'qn': 32,
        'force_host': 2,
        'trackid': ?item.trackId,
      },
      options: Options(
        // 由拦截器补 access_key 并签名；保留国际版的 app-key 头
        extra: {'account': account, keepAppKeyHeader: true},
        headers: _headers,
      ),
    );
  }

  /// 播放心跳（暂停 / 播完 / 退出时）。[progress] 为秒，-1 表示已播完
  static void onHeartbeat({
    required Object? aid,
    required Object cid,
    required int progress,
    required int durationSec,
  }) {
    final session = _session;
    if (session == null || aid == null || aid.toString() != '${session.aid}') {
      return;
    }
    final account = _account;
    if (account == null) return;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final played = progress < 0 ? durationSec : progress;
    session.maxProgress = max(session.maxProgress, played);

    final data = <String, dynamic>{
      ..._identity,
      'access_key': account.accessKey!,
      'aid': session.aid,
      'cid': cid,
      'mid': account.mid,
      'sid': 0,
      'epid': 0,
      'type': 3,
      'sub_type': 0,
      'quality': 0,
      'total_time': max(0, now - session.startTs),
      'paused_time': 0,
      'played_time': played,
      'actual_played_time': played,
      'detail_play_time': played,
      'list_play_time': 0,
      'video_duration': durationSec,
      'last_play_progress_time': played,
      'max_play_progress_time': session.maxProgress,
      'start_ts': session.startTs,
      'play_type': 1,
      'play_mode': 1,
      'play_status': 0,
      'network_type': 1,
      'auto_play': 0,
      'user_status': 0,
      'from': 7,
      'from_spmid': 'tm.recommend.0.0',
      'spmid': 'main.ugc-video-detail.0.0',
      'session': session.session,
      'trackid': ?session.trackId,
    };
    AppSign.appSign(data);

    Request().post(
      '${HttpString.apiBaseUrl}/x/report/heartbeat/mobile',
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        // 已手动签名，拦截器不要再处理
        extra: const {'account': NoAccount()},
        headers: _headers,
      ),
    );
  }
}

class _Session {
  _Session({
    required this.aid,
    required this.trackId,
    required this.startTs,
    required this.session,
  });

  final int aid;
  final String? trackId;
  final int startTs;
  final String session;
  int maxProgress = 0;
}
