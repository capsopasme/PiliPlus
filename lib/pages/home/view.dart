import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/custom_height_widget.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart' show tabBarView;
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends CommonPageState<HomePage>
    with AutomaticKeepAliveClientMixin {
  late ColorScheme _colorScheme;
  final _homeController = Get.putOrFind(HomeController.new);
  final _mainController = Get.find<MainController>();

  @override
  bool get needsCorrection => _homeController.hideTopBar;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = ColorScheme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget tabBar;
    if (_homeController.tabs.length > 1) {
      tabBar = SizedBox(
        height: 52,
        width: double.infinity,
        child: _HomeTabChips(
          controller: _homeController.tabController,
          labels: _homeController.tabs.map((e) => e.label).toList(),
          onTap: (index) {
            feedBack();
            if (_homeController.tabController.index == index) {
              _homeController.animateToTop();
            } else {
              _homeController.tabController.animateTo(index);
            }
          },
        ),
      );
      if (_homeController.hideTopBar &&
          _mainController.barHideType == .instant) {
        tabBar = Material(
          color: _colorScheme.surface,
          child: tabBar,
        );
      }
    } else {
      tabBar = const SizedBox(height: 6);
    }
    return Column(
      children: [
        if (!_mainController.useSideBar &&
            MediaQuery.sizeOf(context).isPortrait)
          customAppBar(),
        tabBar,
        Expanded(
          child: onBuild(
            tabBarView(
              controller: _homeController.tabController,
              children: _homeController.tabs.map((e) => e.page).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget customAppBar() {
    // 尺寸按原设计图相对屏幕宽度换算：搜索框高 38，圆形按钮 33
    const padding = EdgeInsets.fromLTRB(14, 9, 14, 5);
    final child = Row(
      children: [
        searchBar(),
        Obx(
          () => _mainController.accountService.isLogin.value
              ? Padding(
                  padding: const EdgeInsets.only(left: 9),
                  child: _CircleSurface(
                    child: msgBadge(
                      _mainController,
                      compactSize: _CircleSurface.size,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 9),
        _CircleSurface(
          child: userAvatar(
            colorScheme: _colorScheme,
            mainController: _mainController,
            size: 28,
          ),
        ),
      ],
    );
    if (_homeController.hideTopBar) {
      if (_mainController.barOffset case final barOffset?) {
        return Obx(
          () {
            final offset = barOffset.value;
            return CustomHeightWidget(
              offset: Offset(0, -offset),
              height: Style.topBarHeight - offset,
              child: Padding(
                padding: padding,
                child: child,
              ),
            );
          },
        );
      }
      if (_homeController.showTopBar case final showTopBar?) {
        return Obx(() {
          final showSearchBar = showTopBar.value;
          return AnimatedOpacity(
            opacity: showSearchBar ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: AnimatedContainer(
              curve: Curves.easeInOutCubicEmphasized,
              duration: const Duration(milliseconds: 500),
              height: showSearchBar ? Style.topBarHeight : 0,
              padding: padding,
              child: child,
            ),
          );
        });
      }
    }
    return Container(
      height: Style.topBarHeight,
      padding: padding,
      child: child,
    );
  }

  Widget searchBar() {
    const borderRadius = BorderRadius.all(Radius.circular(19));
    return Expanded(
      child: DecoratedBox(
        decoration: _HomeSurface.decoration(_colorScheme, borderRadius),
        child: SizedBox(
          height: 38,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: borderRadius,
              splashColor: _colorScheme.primaryContainer.withValues(
                alpha: 0.3,
              ),
              onTap: () => Get.toNamed(
                '/search',
                parameters: _homeController.enableSearchWord
                    ? {'hintText': _homeController.defaultSearch.value}
                    : null,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: _colorScheme.onSurface,
                    semanticLabel: '搜索',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Obx(
                      () {
                        final word = _homeController.defaultSearch.value;
                        return Text(
                          word.isEmpty ? '搜索视频、UP主或内容…' : word,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: _colorScheme.outline,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 首页顶部这些半透明白色浮层（搜索框、圆形按钮）的统一样式
abstract final class _HomeSurface {
  static BoxDecoration decoration(
    ColorScheme colorScheme,
    BorderRadius borderRadius,
  ) {
    final isDark = colorScheme.brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.85)
          : colorScheme.surfaceContainerLowest.withValues(alpha: 0.82),
      borderRadius: borderRadius,
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 1.5),
              ),
            ],
    );
  }
}

/// 圆形浮层，放消息铃铛/头像
class _CircleSurface extends StatelessWidget {
  const _CircleSurface({required this.child});

  static const double size = 33;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: _HomeSurface.decoration(
          ColorScheme.of(context),
          const BorderRadius.all(Radius.circular(size / 2)),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// 胶囊式标签：选中的实心主题色 + 白字 + 下方短横线，未选中的半透明白色。
///
/// 跟随 [TabController.animation] 过渡颜色，左右滑动页面时颜色同步渐变；
/// 静止时不产生任何重绘。
class _HomeTabChips extends StatelessWidget {
  const _HomeTabChips({
    required this.controller,
    required this.labels,
    required this.onTap,
  });

  final TabController controller;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final isDark = colorScheme.brightness == Brightness.dark;
    final idleBackground = isDark
        ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.7)
        : colorScheme.surfaceContainerLowest.withValues(alpha: 0.6);
    final animation = controller.animation!;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      itemCount: labels.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = (1 - (animation.value - index).abs()).clamp(0.0, 1.0);
            final background = Color.lerp(
              idleBackground,
              colorScheme.primary,
              t,
            )!;
            final foreground = Color.lerp(
              colorScheme.onSurfaceVariant,
              colorScheme.onPrimary,
              t,
            )!;
            return Material(
              color: background,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onTap(index),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: t > 0.5
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                      // 选中项下方的短横线
                      if (t > 0)
                        Positioned(
                          bottom: 2.5,
                          child: Container(
                            width: 9,
                            height: 1.6,
                            decoration: BoxDecoration(
                              color: foreground.withValues(alpha: t),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(0.8),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Widget userAvatar({
  required ColorScheme colorScheme,
  required MainController mainController,
  double size = 34,
}) {
  return Semantics(
    label: "我的",
    child: Obx(
      () {
        if (mainController.accountService.isLogin.value) {
          return Stack(
            clipBehavior: .none,
            children: [
              NetworkImgLayer(
                type: .avatar,
                width: size,
                height: size,
                src: mainController.accountService.face.value,
              ),
              Positioned.fill(
                child: Material(
                  type: .transparency,
                  child: InkWell(
                    onTap: mainController.toMinePage,
                    splashColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    customBorder: const CircleBorder(),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Obx(
                  () => MineController.anonymity.value
                      ? IgnorePointer(
                          child: Container(
                            padding: const .all(2),
                            decoration: BoxDecoration(
                              shape: .circle,
                              color: colorScheme.secondaryContainer,
                            ),
                            child: Icon(
                              size: 14,
                              MdiIcons.incognito,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          );
        }
        return SizedBox(
          width: 38,
          height: 38,
          child: IconButton(
            tooltip: '点击登录',
            style: IconButton.styleFrom(
              padding: .zero,
              backgroundColor: colorScheme.onInverseSurface,
            ),
            onPressed: mainController.toMinePage,
            icon: Icon(
              Icons.person_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
          ),
        );
      },
    ),
  );
}

Widget msgBadge(MainController mainController, {double? compactSize}) {
  return Obx(
    () {
      if (mainController.accountService.isLogin.value) {
        final count = mainController.msgUnReadCount.value;
        final isNumBadge = mainController.msgBadgeMode == .number;
        return IconButton(
          tooltip: '消息',
          iconSize: compactSize == null ? null : compactSize * 0.52,
          style: compactSize == null
              ? null
              : IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.square(compactSize),
                  maximumSize: Size.square(compactSize),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
          onPressed: () {
            mainController
              ..clearUnreadMsg()
              ..lastCheckUnreadAt = DateTime.now().millisecondsSinceEpoch;
            Get.toNamed('/whisper');
          },
          icon: Badge(
            isLabelVisible:
                mainController.msgBadgeMode != .hidden && count != null,
            alignment: isNumBadge
                ? const Alignment(0.0, -0.85)
                : const Alignment(1.0, -0.85),
            label: isNumBadge && count != null ? Text(count) : null,
            largeSize: compactSize == null ? null : 13,
            smallSize: compactSize == null ? null : 5,
            textStyle: compactSize == null
                ? null
                : const TextStyle(fontSize: 8.5),
            padding: compactSize == null
                ? null
                : const EdgeInsets.symmetric(horizontal: 4),
            child: const Icon(Icons.notifications_none),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
