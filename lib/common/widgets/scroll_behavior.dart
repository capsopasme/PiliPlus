import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/scroll_physics.dart'
    show iosFlingScrollPhysics;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:material_ui/material_ui.dart';

const Set<PointerDeviceKind> desktopDragDevices = {
  .touch,
  .mouse,
  .trackpad,
  .stylus,
  .invertedStylus,
  .unknown,
};

/// Android（手机）全局滚动行为：iOS 惯性曲线 + 边界夹紧，保留系统拉伸效果
class MobileScrollBehavior extends MaterialScrollBehavior {
  const MobileScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      iosFlingScrollPhysics;
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (Platform.isAndroid) {
      return iosFlingScrollPhysics;
    }
    return super.getScrollPhysics(context);
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (Platform.isAndroid) {
      return StretchingOverscrollIndicator(
        axisDirection: details.direction,
        clipBehavior: details.decorationClipBehavior ?? .hardEdge,
        child: child,
      );
    }
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => desktopDragDevices;
}

class NoOverscrollIndicator extends CustomScrollBehavior {
  const NoOverscrollIndicator();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
