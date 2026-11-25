import 'package:material_ui/material_ui.dart';

/// 加载占位骨架。
///
/// 原实现每个骨架项各持有一个循环动画，每帧 setState 重建并通过 ShaderMask
/// 做一次离屏合成（saveLayer）来画扫光；列表里往往同时有 5~8 个骨架项，
/// 加载期间（以及页面过渡期间）会以满刷新率持续出帧。
/// 现在改为静态灰块：不再占用 Ticker，也没有离屏合成，静止时零开销。
class Skeleton extends StatelessWidget {
  final Widget child;

  const Skeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
