import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/download/download_info.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

/// 离线缓存中的分组卡片
class DownloadGroupItem extends StatelessWidget {
  const DownloadGroupItem({
    super.key,
    required this.info,
    required this.onTap,
    required this.onLongPress,
  });

  final DownloadGroupInfo info;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final items = info.items;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Style.safeSpace,
            vertical: 5,
          ),
          child: Row(
            spacing: 10,
            children: [
              Stack(
                clipBehavior: .none,
                children: [
                  AspectRatio(
                    aspectRatio: Style.aspectRatio,
                    child: items.isEmpty
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: Style.mdRadius,
                            ),
                            child: Icon(
                              Icons.folder_outlined,
                              size: 36,
                              color: colorScheme.outline,
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) => NetworkImgLayer(
                              src: items.first.cover,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                            ),
                          ),
                  ),
                  const PBadge(text: '分组', top: 6.0, right: 6.0),
                  PBadge(
                    text: '${info.videoCount}个视频',
                    right: 6.0,
                    bottom: 6.0,
                    isBold: false,
                    type: .gray,
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: .start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 4),
                            child: Icon(
                              Icons.folder,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              info.group.name,
                              style: const TextStyle(
                                height: 1.42,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      items.isEmpty ? '空分组' : '${items.length}项',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 输入分组名称
Future<String?> showDownloadGroupNameDialog(
  BuildContext context, {
  required String title,
  String? initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _GroupNameDialog(title: title, initialName: initialName),
  );
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({required this.title, this.initialName});

  final String title;
  final String? initialName;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  // 由对话框自己持有并在 dispose 中释放，避免关闭动画期间使用已释放的 controller
  late final _textController = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _textController.text.trim();
    if (name.isEmpty) return;
    Get.back(result: name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _textController,
        autofocus: true,
        maxLength: 30,
        decoration: const InputDecoration(hintText: '分组名称'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}
