import 'dart:io';

import 'package:PiliPlus/common/skeleton/video_reply.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_style.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_thread.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

ReplyInfo _reply(
  int id,
  String name,
  String msg, {
  List<ReplyInfo> replies = const [],
  int count = 0,
  int like = 0,
  bool liked = false,
  int root = 0,
}) => ReplyInfo(
  id: Int64(id),
  oid: Int64(100),
  type: Int64(1),
  mid: Int64(id + 1000),
  root: Int64(root),
  parent: Int64(root),
  dialog: Int64(id),
  like: Int64(like),
  ctime: Int64(1700000000),
  count: Int64(count),
  content: Content(message: msg),
  member: Member(
    mid: Int64(id + 1000),
    name: name,
    face: '',
    level: Int64(5),
  ),
  replyControl: ReplyControl(
    location: 'IP属地：上海',
    action: liked ? Int64.ONE : Int64.ZERO,
  ),
  replies: replies,
);

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('piliplus-reply-ui-');
    Hive.init(tempDir.path);
    GStorage.regAdapter();
    GStorage.setting = await Hive.openBox('setting');
    GStorage.localCache = await Hive.openBox('localCache');
    GStorage.video = await Hive.openBox('video');
    GStorage.historyWord = await Hive.openBox('historyWord');
  });

  // 不在 tearDown 里 Hive.close()：构建期间若有写入挂在 FakeAsync 区里，
  // close 会一直等它而卡住。临时目录交给系统清理。

  Widget host(List<Widget> children, {Brightness brightness = .light}) =>
      MaterialApp(
        theme: ThemeData(brightness: brightness, colorSchemeSeed: Colors.pink),
        home: Scaffold(
          body: SizedBox(
            width: 393,
            child: ListView(children: children),
          ),
        ),
      );

  testWidgets('level-1 card: thread preview, collapse, expand', (tester) async {
    final store = ReplyThreadStore();
    final root = _reply(
      1,
      'Alice',
      '很长的评论内容' * 60,
      count: 12,
      like: 12345,
      liked: true,
      replies: [
        _reply(2, 'Bob', '回复 @Alice :你好', like: 3, root: 1),
        _reply(
          3,
          'Carol with a very very very long nickname here',
          '第二行\n换行',
          root: 1,
        ),
        _reply(12, 'Dan', 'third', root: 1),
        _reply(13, 'Erin', 'fourth (hidden by default)', root: 1),
      ],
    );
    await tester.pumpWidget(
      host([
        ReplyItemGrpc(
          replyItem: root,
          replyLevel: 1,
          threadStore: store,
          upMid: Int64(1001),
          replyReply: (_, _) {},
        ),
        ReplyItemGrpc(
          replyItem: _reply(9, 'NoReplies', 'short'),
          replyLevel: 1,
          threadStore: store,
        ),
      ]),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Dan'), findsOneWidget);
    // 默认只显示前 3 条
    expect(find.text('Erin'), findsNothing);
    expect(find.textContaining('展开 9 条回复'), findsOneWidget);

    // 点头部（时间·属地行）整串折叠
    await tester.tap(find.textContaining('IP属地').first);
    await tester.pumpAndSettle();
    expect(find.text('12 条回复'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    // 点折叠行展开
    await tester.tap(find.text('12 条回复'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    expect(find.textContaining('展开 9 条回复'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level 0 / 2 / 3, skeleton, dark, both backgrounds', (
    tester,
  ) async {
    for (final (brightness, bg) in [
      for (final b in Brightness.values)
        for (final t in ReplyBackgroundType.values) (b, t),
    ]) {
      ReplyPalette.backgroundType.value = bg;
      await tester.pumpWidget(
        host([
          const ReplyBackground(child: SizedBox(height: 40)),
          const VideoReplySkeleton(),
          ReplyItemGrpc(
            replyItem: _reply(4, 'Dave', 'level two root (panel header)'),
            replyLevel: 2,
            needDivider: false,
          ),
          ReplyItemGrpc(
            replyItem: _reply(5, 'Eve', 'level two with dialog', root: 4),
            replyLevel: 2,
            showDialogue: () {},
          ),
          ReplyItemGrpc(
            replyItem: _reply(6, 'Frank', 'level three', root: 4),
            replyLevel: 3,
          ),
          ReplyItemGrpc(
            replyItem: _reply(
              7,
              'Grace',
              'flat',
              count: 3,
              replies: [_reply(8, 'Heidi', 'x', root: 7)],
            ),
            replyLevel: 0,
            needDivider: false,
          ),
          ReplyItemGrpc(
            replyItem: _reply(
              10,
              'NoStore',
              'level one without store',
              count: 5,
              replies: [_reply(11, 'Ivan', 'y', root: 10)],
            ),
            replyLevel: 1,
          ),
        ], brightness: brightness),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Dave'), findsOneWidget);
      expect(find.textContaining('共5条回复'), findsOneWidget);
    }
  });
}
