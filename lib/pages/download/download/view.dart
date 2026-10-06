import 'dart:async';

import 'package:PiliPlus/common/widgets/appbar/appbar.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/common/widgets/flutter/pop_scope.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/download_group.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/download/detail/widgets/item.dart';
import 'package:PiliPlus/pages/download/download/controller.dart';
import 'package:PiliPlus/pages/download/download/widgets/group.dart';
import 'package:PiliPlus/pages/download/download/widgets/page.dart';
import 'package:PiliPlus/pages/download/download/widgets/season.dart';
import 'package:PiliPlus/pages/download/download_action_mixin.dart';
import 'package:PiliPlus/pages/download/search/view.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:collection/collection.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key, this.groupId});

  /// 不为空时显示该手动分组内的缓存
  final String? groupId;

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with GridMixin, BaseDownloadActionMixin<DownloadPage, DownloadSeasonInfo> {
  final _progress = ChangeNotifier();
  late final _controller = Get.put(
    DownloadController(groupId: widget.groupId),
    tag: widget.groupId,
  );

  bool get _isGroupPage => widget.groupId != null;

  @override
  final downloadService = Get.find<DownloadService>();

  @override
  BaseMultiSelectMixin<DownloadSeasonInfo> get multiSelectCtr => _controller;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Future<void> onUpdate(
    Future<bool> Function(BiliDownloadEntryInfo e) toElement,
  ) async {
    if (checkUpdateCount(_controller.checkedCount)) return;

    bool dismiss = false;
    SmartDialog.showLoading(
      onDismiss: () {
        dismiss = true;
        _controller.handleSelect();
      },
    );

    bool isSuccess = true;
    for (final chunk in _controller.allChecked.mapChunked(
      kUpdateConcurrency,
      (season) async {
        bool isSuccess = true;
        for (final chunk in season.pages.mapChunked(
          kUpdateConcurrency,
          (page) async {
            bool isSuccess = true;
            for (final chunk in page.entries.mapChunked(
              kUpdateConcurrency,
              toElement,
            )) {
              final res = await Future.wait(chunk);
              if (res.any((e) => !e)) isSuccess = false;
              if (dismiss) break;
            }
            return isSuccess;
          },
        )) {
          final res = await Future.wait(chunk);
          if (res.any((e) => !e)) isSuccess = false;
          if (dismiss) break;
        }
        return isSuccess;
      },
    )) {
      final res = await Future.wait(chunk);
      if (res.any((e) => !e)) isSuccess = false;
      if (dismiss) break;
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  Future<void> _updateSeasonDm(DownloadSeasonInfo seasonInfo) async {
    if (checkUpdateCount(
      seasonInfo.pages.fold(0, (a, b) => a + b.entries.length),
    )) {
      return;
    }

    bool dismiss = false;
    SmartDialog.showLoading(onDismiss: () => dismiss = true);

    bool isSuccess = true;

    for (final page in seasonInfo.pages) {
      for (final chunk in page.entries.mapChunked(
        kUpdateConcurrency,
        (e) => downloadService.downloadDanmaku(
          entry: e,
          isUpdate: true,
        ),
      )) {
        final res = await Future.wait(chunk);
        if (res.any((e) => !e)) isSuccess = false;
        if (dismiss) break;
      }
    }

    toastUpdateResult(dismiss, isSuccess);
  }

  static const _kNewGroup = '_new';
  static const _kUngroup = '_ungroup';

  Future<void> _createGroup() async {
    final name = await showDownloadGroupNameDialog(context, title: '新建分组');
    if (name == null) return;
    await downloadService.createGroup(name);
  }

  /// 多选后「移动」：移到已有分组 / 新建分组 / 移出分组
  Future<void> _showMoveDialog() async {
    if (_controller.checkedCount == 0) return;
    // 先取出选中项：新建分组会刷新列表、清掉选中状态
    final keys = _controller.checkedKeys;
    final currentId = widget.groupId;
    final res = await showDialog<Object>(
      context: context,
      builder: (context) {
        Widget option(IconData icon, String text, Object result) =>
            DialogOption(
              onPressed: () => Get.back(result: result),
              child: Row(
                spacing: 12,
                children: [
                  Icon(icon, size: 20),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
        return SimpleDialog(
          clipBehavior: Clip.hardEdge,
          title: const Text('移动到分组'),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            option(Icons.create_new_folder_outlined, '新建分组', _kNewGroup),
            if (currentId != null)
              option(Icons.drive_file_move_outline, '移出分组', _kUngroup),
            for (final group in downloadService.downloadGroups)
              if (group.id != currentId)
                option(Icons.folder_outlined, group.name, group),
          ],
        );
      },
    );
    if (res == null || !mounted) return;
    DownloadGroup? target;
    if (res == _kNewGroup) {
      final name = await showDownloadGroupNameDialog(context, title: '新建分组');
      if (name == null) return;
      target = await downloadService.createGroup(name);
      if (target == null) return;
    } else if (res is DownloadGroup) {
      target = res;
    }
    await _controller.moveToGroup(keys, target);
    SmartDialog.showToast(
      target == null ? '已移出分组' : '已移动到「${target.name}」',
    );
  }

  void _onGroupLongPress(DownloadGroupInfo info) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        clipBehavior: Clip.hardEdge,
        title: Text(info.group.name),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          DialogOption(
            onPressed: () async {
              Get.back();
              final name = await showDownloadGroupNameDialog(
                this.context,
                title: '重命名分组',
                initialName: info.group.name,
              );
              if (name != null) {
                downloadService.renameGroup(info.group, name);
              }
            },
            child: const Text('重命名', style: TextStyle(fontSize: 14)),
          ),
          DialogOption(
            onPressed: () {
              Get.back();
              downloadService.removeGroup(info.group);
            },
            child: const Text(
              '解散分组（视频移回列表）',
              style: TextStyle(fontSize: 14),
            ),
          ),
          if (info.items.isNotEmpty)
            DialogOption(
              onPressed: () {
                Get.back();
                showConfirmDialog(
                  context: this.context,
                  title: Text('删除分组「${info.group.name}」及其中视频？'),
                  content: Text('将删除 ${info.videoCount} 个视频的缓存文件'),
                  onConfirm: () => _controller.deleteGroupWithVideos(info),
                );
              },
              child: Text(
                '删除分组及其中视频',
                style: TextStyle(fontSize: 14, color: colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroups(bool hasQueue) {
    return Obx(() {
      final groups = _controller.groups;
      if (groups.isEmpty || _controller.enableMultiSelect.value) {
        return const SliverToBoxAdapter();
      }
      return SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(left: 12, bottom: 7, top: hasQueue ? 7 : 0),
            sliver: const SliverToBoxAdapter(child: Text('分组')),
          ),
          SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final info = groups[index];
              return DownloadGroupItem(
                info: info,
                onTap: () => Get.to(DownloadPage(groupId: info.group.id)),
                onLongPress: () => _onGroupLongPress(info),
              );
            },
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Obx(() {
      final enableMultiSelect = _controller.enableMultiSelect.value;
      return popScope(
        canPop: !enableMultiSelect,
        onPopInvokedWithResult: (didPop, result) {
          if (enableMultiSelect) {
            _controller.handleSelect();
          }
        },
        child: SimpleScaffold(
          appBar: MultiSelectAppBarWidget(
            ctr: _controller,
            actions: [
              TextButton(
                style: TextButton.styleFrom(visualDensity: .compact),
                onPressed: _showMoveDialog,
                child: Text(
                  '移动',
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              ),
              updateBtn(),
            ],
            child: AppBar(
              title: _isGroupPage
                  ? Obx(() => Text(_controller.groupName.value ?? '分组'))
                  : const Text('离线缓存'),
              actions: [
                if (_isGroupPage)
                  IconButton(
                    tooltip: '重命名分组',
                    onPressed: () async {
                      final group = downloadService.findGroup(widget.groupId!);
                      if (group == null) return;
                      final name = await showDownloadGroupNameDialog(
                        context,
                        title: '重命名分组',
                        initialName: group.name,
                      );
                      if (name != null) {
                        downloadService.renameGroup(group, name);
                      }
                    },
                    icon: const Icon(Icons.drive_file_rename_outline),
                  )
                else ...[
                  IconButton(
                    tooltip: '新建分组',
                    onPressed: _createGroup,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                  IconButton(
                    tooltip: '搜索',
                    onPressed: () async {
                      await downloadService.waitForInitialization;
                      if (!mounted) return;
                      Get.to(DownloadSearchPage(progress: _progress));
                    },
                    icon: const Icon(Icons.search),
                  ),
                ],
                IconButton(
                  tooltip: '多选',
                  onPressed: () {
                    if (enableMultiSelect) {
                      _controller.handleSelect();
                    } else {
                      _controller.enableMultiSelect.value = true;
                    }
                  },
                  icon: const Icon(Icons.edit_note),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          body: Padding(
            padding: EdgeInsets.only(left: padding.left, right: padding.right),
            child: CustomScrollView(
              slivers: [
                // Obx 内必须读取可观察对象，分组页不显示下载队列，直接不构建
                if (!_isGroupPage) Obx(() {
                  final entry =
                      downloadService.waitDownloadQueue.firstWhereOrNull(
                        (e) => e.cid == downloadService.curCid,
                      ) ??
                      downloadService.waitDownloadQueue.firstOrNull;
                  if (entry != null) {
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.only(left: 12, bottom: 7),
                          sliver: SliverToBoxAdapter(
                            child: Text(
                              '正在缓存 (${downloadService.waitDownloadQueue.length})',
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 110,
                            child: DetailItem(
                              entry: entry,
                              progress: _progress,
                              downloadService: downloadService,
                              showTitle: true,
                              isCurr: true,
                              controller: _controller,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return const SliverToBoxAdapter();
                }),
                if (!_isGroupPage)
                  _buildGroups(downloadService.waitDownloadQueue.isNotEmpty),
                Obx(() {
                  final hasQueue =
                      !_isGroupPage &&
                      downloadService.waitDownloadQueue.isNotEmpty;
                  final hasGroups =
                      !_isGroupPage &&
                      _controller.groups.isNotEmpty &&
                      !enableMultiSelect;
                  if (_controller.seasons.isNotEmpty) {
                    return SliverMainAxisGroup(
                      slivers: [
                        if (!_isGroupPage)
                          SliverPadding(
                            padding: EdgeInsets.only(
                              left: 12,
                              bottom: 7,
                              top: hasQueue || hasGroups ? 7 : 0,
                            ),
                            sliver: const SliverToBoxAdapter(
                              child: Text('已缓存视频'),
                            ),
                          ),
                        SliverGrid.builder(
                          gridDelegate: gridDelegate,
                          itemBuilder: (context, index) {
                            final season = _controller.seasons[index];
                            final seasonInfo = season.seasonInfo;
                            final pages = season.pages;

                            if (seasonInfo != null && pages.length > 1) {
                              return SeasonInfoItem(
                                controller: _controller,
                                downloadService: downloadService,
                                seasonInfo: seasonInfo,
                                season: season,
                                enableMultiSelect: enableMultiSelect,
                                progress: _progress,
                                updateSeasonDm: _updateSeasonDm,
                              );
                            }

                            final page = pages.first;
                            if (pages.length == 1 && page.entries.length == 1) {
                              final entry = page.entries.first;
                              return DetailItem(
                                entry: entry,
                                progress: _progress,
                                downloadService: downloadService,
                                showTitle: true,
                                onDelete: () {
                                  downloadService.deleteDownload(
                                    entry: entry,
                                    removeList: true,
                                  );
                                  GStorage.watchProgress.delete(
                                    entry.cid.toString(),
                                  );
                                },
                                checked: season.checked,
                                onSelect: (_) => _controller.onSelect(season),
                                controller: _controller,
                              );
                            }

                            return PageInfoItem(
                              controller: _controller,
                              downloadService: downloadService,
                              seasonInfo: season,
                              pageInfo: page,
                              enableMultiSelect: enableMultiSelect,
                              progress: _progress,
                              updatePageDm: updatePageDm,
                            );
                          },
                          itemCount: _controller.seasons.length,
                        ),
                      ],
                    );
                  }
                  if (_isGroupPage) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          _controller.groupName.value == null
                              ? '分组已删除'
                              : '分组为空\n在「离线缓存」中多选视频后点「移动」加入',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.outline),
                        ),
                      ),
                    );
                  }
                  if (hasQueue || hasGroups) {
                    return const SliverToBoxAdapter();
                  }
                  return const HttpError();
                }),
                SliverToBoxAdapter(
                  child: SizedBox(height: padding.bottom + 100),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
