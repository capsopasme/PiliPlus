import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_group.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show MultiSelectData;
import 'package:path/path.dart' as path;

class DownloadPageInfo with MultiSelectData {
  final String pageId;
  final String dirPath;
  final String title;
  String cover;
  int sortKey;
  final int? seasonType;
  final List<BiliDownloadEntryInfo> entries;

  DownloadPageInfo({
    required this.pageId,
    required this.dirPath,
    required this.title,
    required this.cover,
    required this.sortKey,
    this.seasonType,
    required this.entries,
  });
}

class DownloadSeasonInfo with MultiSelectData {
  SeasonInfo? seasonInfo;
  final String pageId;
  final List<DownloadPageInfo> pages;

  DownloadSeasonInfo({
    required this.seasonInfo,
    required this.pageId,
    required this.pages,
  });

  /// 手动分组用的稳定标识：合集按合集 id；其余按缓存目录名
  /// （普通视频为 avid，番剧/课程为 s_季度id，两者不会冲突）
  String get groupKey {
    if (seasonInfo case final season?) {
      return 's:${season.id}';
    }
    return 'p:${path.basename(pages.first.dirPath)}';
  }

  String get cover => seasonInfo?.cover ?? pages.first.cover;

  int get videoCount => pages.fold(0, (sum, page) => sum + page.entries.length);
}

/// 离线缓存页面中一个分组的展示数据
class DownloadGroupInfo {
  const DownloadGroupInfo(this.group, this.items);

  final DownloadGroup group;
  final List<DownloadSeasonInfo> items;

  int get videoCount => items.fold(0, (sum, item) => sum + item.videoCount);
}
