import 'dart:async';

import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/models_new/download/download_group.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart'
    show BaseMultiSelectMixin;
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' show Text;

class DownloadController extends GetxController
    with BaseMultiSelectMixin<DownloadSeasonInfo> {
  DownloadController({this.groupId});

  /// 不为空时是分组页，只显示该分组内的条目
  final String? groupId;

  final _downloadService = Get.find<DownloadService>();

  /// 主页面：未分组的条目；分组页：组内条目
  final seasons = RxList<DownloadSeasonInfo>();

  /// 全部条目（不区分分组），供合集/分P详情页和离线播放列表查找
  List<DownloadSeasonInfo> allSeasons = const [];

  /// 主页面显示的分组
  final groups = RxList<DownloadGroupInfo>();

  /// 分组页的分组名，分组被删除后为 null
  final groupName = Rxn<String>();

  final flag = RxInt(0);

  @override
  List<DownloadSeasonInfo> get list => seasons;
  @override
  RxList<DownloadSeasonInfo> get state => seasons;

  @override
  void onInit() {
    super.onInit();
    if (groupId case final id?) {
      groupName.value = _downloadService.findGroup(id)?.name;
    }
    _loadList();
    _downloadService.flagNotifier.add(_loadList);
  }

  @override
  void onClose() {
    _downloadService.flagNotifier.remove(_loadList);
    super.onClose();
  }

  Future<void> _loadList() async {
    await _downloadService.waitForInitialization;
    if (isClosed) return;
    final list = <DownloadSeasonInfo>[];
    for (final entry in _downloadService.downloadList) {
      final pageId = entry.pageId;
      final seasonInfo = entry.seasonInfo;
      final season = seasonInfo != null
          ? list.firstWhereOrNull((e) => e.seasonInfo == seasonInfo)
          : list.firstWhereOrNull((e) => e.pageId == pageId);
      if (season != null) {
        final page = season.pages.firstWhereOrNull((e) => e.pageId == pageId);
        if (page != null) {
          final aSortKey = entry.sortKey;
          final bSortKey = page.sortKey;
          if (aSortKey < bSortKey) {
            page
              ..cover = entry.cover
              ..sortKey = aSortKey;
          }
          page.entries.add(entry);
        } else {
          season.pages.add(
            entry.toDownloadPageInfo(pageId, sortKey: seasonInfo!.index),
          );
        }
      } else {
        list.add(
          DownloadSeasonInfo(
            pageId: pageId,
            seasonInfo: seasonInfo,
            pages: [
              entry.toDownloadPageInfo(pageId, sortKey: seasonInfo?.index),
            ],
          ),
        );
      }
    }
    allSeasons = list;
    _applyGroups(list);
    flag.value++;
  }

  void _applyGroups(List<DownloadSeasonInfo> list) {
    final allGroups = _downloadService.downloadGroups;

    if (groupId case final id?) {
      final group = _downloadService.findGroup(id);
      groupName.value = group?.name;
      if (group == null) {
        seasons.clear();
        return;
      }
      final keys = group.keys.toSet();
      seasons.value = list.where((e) => keys.contains(e.groupKey)).toList();
      return;
    }

    final keyToGroup = <String, String>{};
    final members = <String, List<DownloadSeasonInfo>>{};
    for (final group in allGroups) {
      members[group.id] = <DownloadSeasonInfo>[];
      for (final key in group.keys) {
        keyToGroup[key] = group.id;
      }
    }
    final ungrouped = <DownloadSeasonInfo>[];
    for (final season in list) {
      final id = keyToGroup[season.groupKey];
      if (id == null) {
        ungrouped.add(season);
      } else {
        members[id]!.add(season);
      }
    }
    seasons.value = ungrouped;
    groups.value = [
      for (final group in allGroups) DownloadGroupInfo(group, members[group.id]!),
    ];
  }

  /// 当前选中条目的分组标识（移动分组前先取出：新建分组会刷新列表、清掉选中状态）
  List<String> get checkedKeys => allChecked.map((e) => e.groupKey).toList();

  Future<void> moveToGroup(List<String> keys, DownloadGroup? target) {
    if (enableMultiSelect.value) {
      rxCount.value = 0;
      enableMultiSelect.value = false;
    }
    return _downloadService.moveToGroup(keys, target);
  }

  Future<void> _deleteSeasons(Iterable<DownloadSeasonInfo> items) async {
    final watchProgress = GStorage.watchProgress;
    for (final season in items) {
      for (final page in season.pages) {
        await watchProgress.deleteAll(
          page.entries.map((e) => e.cid.toString()),
        );
        await _downloadService.deletePage(
          pageDirPath: page.dirPath,
          refresh: false,
        );
      }
    }
  }

  /// 删除分组及组内所有缓存文件
  Future<void> deleteGroupWithVideos(DownloadGroupInfo info) async {
    SmartDialog.showLoading();
    try {
      await _deleteSeasons(info.items.toList());
      await _downloadService.removeGroup(info.group);
    } finally {
      SmartDialog.dismiss();
    }
  }

  @override
  void onRemove() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('确定删除选中视频？'),
      onConfirm: () async {
        SmartDialog.showLoading();
        await _deleteSeasons(allChecked.toList());
        _downloadService.flagNotifier.refresh();
        if (enableMultiSelect.value) {
          rxCount.value = 0;
          enableMultiSelect.value = false;
        }
        SmartDialog.dismiss();
      },
    );
  }
}
