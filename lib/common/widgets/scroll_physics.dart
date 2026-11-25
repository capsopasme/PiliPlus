import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

Widget tabBarView({
  required List<Widget> children,
  TabController? controller,
  HitTestBehavior hitTestBehavior = .opaque,
}) => TabBarView(
  controller: controller,
  physics: tabBarScrollPhysics,
  hitTestBehavior: hitTestBehavior,
  horizontalDragGestureRecognizer: CustomHorizontalDragGestureRecognizer.new,
  children: children,
);

SpringDescription kSpringDescription = _customSpringDescription();

SpringDescription _customSpringDescription() {
  final List<double> springDescription = Pref.springDescription;
  return SpringDescription(
    mass: springDescription[0],
    stiffness: springDescription[1],
    damping: springDescription[2],
  );
}

const tabBarScrollPhysics = _TabBarViewScrollPhysics();

class _TabBarViewScrollPhysics extends ClampingScrollPhysics {
  const _TabBarViewScrollPhysics({super.parent});

  @override
  _TabBarViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _TabBarViewScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => kSpringDescription;
}

mixin ReloadMixin {
  late bool reload = false;
}

class ReloadScrollPhysics extends AlwaysScrollableScrollPhysics {
  const ReloadScrollPhysics({super.parent, required this.controller});

  final ReloadMixin controller;

  @override
  ReloadScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReloadScrollPhysics(
      parent: buildParent(ancestor),
      controller: controller,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (controller.reload) {
      controller.reload = false;
      return 0;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

/// Android 也使用 iOS 的惯性曲线（摩擦减速、连续快滑叠加速度），
/// 但边界保持夹紧（不回弹），与原有下拉刷新/嵌套滚动的行为一致。
final bool useIOSFling = PlatformUtils.isDarwin || Platform.isAndroid;

final platformClampingPhysics = useIOSFling
    ? const BouncingScrollPhysicsExt()
    : const ClampingScrollPhysics();

final platformAlwaysClampingPhysics = useIOSFling
    ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysicsExt())
    : const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());

/// 作为 [ScrollBehavior.getScrollPhysics] 的默认值
const iosFlingScrollPhysics = BouncingScrollPhysicsExt(
  parent: RangeMaintainingScrollPhysics(),
);

class BouncingScrollPhysicsExt extends BouncingScrollPhysics
    with ClampingBoundaryMixin {
  const BouncingScrollPhysicsExt({super.parent});

  @override
  BouncingScrollPhysicsExt applyTo(ScrollPhysics? ancestor) {
    return BouncingScrollPhysicsExt(parent: buildParent(ancestor));
  }

  /// iOS 摩擦模型的速度按指数衰减，默认要降到约 7 px/s 才结束，
  /// 最后约半秒每帧只移动零点几个物理像素，肉眼看不出却要以满刷新率持续出帧。
  /// 把结束速度提到约每帧半个物理像素（按 120Hz 计），尾段直接停住，
  /// 观感不变，每次快滑能少渲染几十帧。
  @override
  Tolerance toleranceFor(ScrollMetrics metrics) {
    final Tolerance base = super.toleranceFor(metrics);
    return Tolerance(
      distance: base.distance,
      time: base.time,
      velocity: math.max(base.velocity, 60.0 / metrics.devicePixelRatio),
    );
  }
}

/// [ClampingScrollPhysics.applyBoundaryConditions]
mixin ClampingBoundaryMixin on ScrollPhysics {
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      // Underscroll.
      return value - position.pixels;
    }
    if (position.maxScrollExtent <= position.pixels &&
        position.pixels < value) {
      // Overscroll.
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      // Hit top edge.
      return value - position.minScrollExtent;
    }
    if (position.pixels < position.maxScrollExtent &&
        position.maxScrollExtent < value) {
      // Hit bottom edge.
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }
}
