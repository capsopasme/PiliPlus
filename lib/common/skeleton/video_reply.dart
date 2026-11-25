import 'package:PiliPlus/pages/video/reply/widgets/reply_style.dart';
import 'package:material_ui/material_ui.dart';

/// 评论加载占位：与一级评论同样的布局 + 静态灰块 + 底部细线
class VideoReplySkeleton extends StatelessWidget {
  const VideoReplySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ReplyPalette.of(context);
    final fill = palette.fill;
    Widget bar(double width, double height) => SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ReplyStyle.rootPadding,
            12,
            ReplyStyle.rootPadding,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox.square(
                    dimension: ReplyStyle.avatarSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: fill,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: ReplyStyle.avatarGap),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(84, 12),
                      const SizedBox(height: 6),
                      bar(56, 10),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: ReplyStyle.contentIndent,
                  top: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(double.infinity, 13),
                    const SizedBox(height: 8),
                    bar(180, 13),
                  ],
                ),
              ),
            ],
          ),
        ),
        ReplyDivider(color: palette.divider),
      ],
    );
  }
}
