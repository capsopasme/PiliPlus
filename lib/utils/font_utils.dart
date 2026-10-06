import 'dart:ffi';
import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'dart:ui' show loadFontFromList;

import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/fontconfig.g.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, defaultTargetPlatform, debugPrint;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:jni/jni.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

typedef AppFont = ({String? fontFamily, bool isCustom});

/// 系统字体文件及其在 ttc 中的序号
typedef _SysFont = ({String path, int index});

abstract final class FontUtils {
  static final _fonts = <String>{};
  static bool _initialized = false;

  static const _kFontExts = ['ttf', 'ttc', 'otf'];

  static AppFont _appFont = _initAppFont();
  static AppFont get appFont => _appFont;
  static set appFont(AppFont value) {
    assert(value.isCustom == _isCutsomFont(value.fontFamily));
    _appFont = value;
  }

  static bool _isCutsomFont(String? fontFamily) {
    return fontFamily?.contains('/') ?? false;
  }

  static AppFont _initAppFont() {
    final String? appFont = GStorage.setting.get(SettingBoxKey.appFont);
    if (_isCutsomFont(appFont)) {
      if (fontFile.existsSync()) {
        return (fontFamily: appFont, isCustom: true);
      } else {
        GStorage.setting.delete(SettingBoxKey.appFont);
        return const (fontFamily: null, isCustom: false);
      }
    } else {
      return (fontFamily: appFont, isCustom: false);
    }
  }

  static String? get fontFamily => _appFont.fontFamily;
  static bool get isCustom => _appFont.isCustom;

  static final fontFile = File(path.join(appSupportDirPath, 'customFont.otf'));

  static Future<void>? init() {
    if (isCustom) {
      return _readAndLoad();
    }
    if (Platform.isAndroid && _appFont.fontFamily == null) {
      return syncSystemFont();
    }
    return null;
  }

  // ---------------- 跟随系统默认字体（Android） ----------------

  static const _sysSansFamily = 'PiliSysSans';
  static const _sysCjkFamily = 'PiliSysCJK';

  static String? _sysFontFamily;
  static List<String>? _sysFontFamilyFallback;
  static final _loadedSysFonts = <String>{};

  /// 系统排版实际用来显示中文（常规字重）的字体文件名，仅用于设置页展示
  static String? systemCjkFontName;

  /// 「默认」字体对应的字体族；与 Flutter 自带的选择一致时为 null
  static String? get systemFontFamily => _sysFontFamily;
  static List<String>? get systemFontFamilyFallback => _sysFontFamilyFallback;

  /// 主题使用的字体族：用户选了字体就用用户的，否则跟随系统默认字体
  static String? get themeFontFamily => _appFont.fontFamily ?? _sysFontFamily;
  static List<String>? get themeFontFamilyFallback =>
      _appFont.fontFamily == null ? _sysFontFamilyFallback : null;

  /// 让「默认」字体与系统实际使用的字体一致（Android 12+）。
  ///
  /// Flutter 自己解析 /system/etc/fonts.xml 选字体，而 Android 15 起系统改读
  /// font_fallback.xml，字体模块/主题若只改了后者，Flutter 应用里就还是原来的字体。
  /// 这里先问系统真正用来画默认文字的是哪个字体文件，与 fonts.xml 对比：
  /// 一致时什么都不做（不多占内存），不一致才把系统用的字体文件加载进来。
  /// 可重复调用（字重变化时只补加载缺少的文件）。
  static Future<void> syncSystemFont({bool force = false}) async {
    if (!Platform.isAndroid || (!force && _appFont.fontFamily != null)) {
      return;
    }
    try {
      final sys = _querySystemFonts();
      if (sys == null) return;
      final flutterFonts = await _readFontsXml();
      if (flutterFonts == null) return;

      final weights = {400, 700, (Pref.appFontWeight.index + 1) * 100};
      Set<_SysFont>? pick(Map<int, _SysFont> fonts, Iterable<int> weights) {
        final result = <_SysFont>{};
        for (final weight in weights) {
          if ((fonts[weight] ?? fonts[400]) case final font?) result.add(font);
        }
        return result.isEmpty ? null : result;
      }

      if ((sys.cjk[400] ?? (sys.cjk.isEmpty ? null : sys.cjk.values.first))
          case final font?) {
        systemCjkFontName = path.basename(font.path);
      }

      var latin = pick(sys.latin, weights);
      var cjk = pick(sys.cjk, weights);

      // 只加载常用字重，单个 CJK 字体动辄十几 MB，总量过大时只保留常规字重
      int totalBytes(Set<_SysFont>? fonts) =>
          fonts?.fold<int>(0, (sum, font) {
            try {
              return sum + File(font.path).lengthSync();
            } catch (_) {
              return sum;
            }
          }) ??
          0;
      if (totalBytes(latin) + totalBytes(cjk) > 80 * 0x100000) {
        latin = pick(sys.latin, const [400]);
        cjk = pick(sys.cjk, const [400]);
      }

      bool differs(Set<_SysFont>? fonts, Set<String>? used) =>
          fonts != null &&
          (used == null || fonts.any((font) => !used.contains(_fontKey(font))));
      // loadFontFromList 只能加载 ttc 中的第 0 个字体
      bool loadable(Set<_SysFont> fonts) =>
          fonts.every((font) => font.index == 0);

      final loadLatin =
          differs(latin, flutterFonts.latin) &&
          loadable(latin!) &&
          await _loadSysFonts(latin, _sysSansFamily);
      final loadCjk =
          differs(cjk, flutterFonts.cjk) &&
          loadable(cjk!) &&
          // 西文字体本身就包含中文（整套替换的字体）时无需再单独加载
          !(loadLatin && latin!.containsAll(cjk)) &&
          await _loadSysFonts(cjk, _sysCjkFamily);

      // 只换了中文字体时，西文仍用系统 sans-serif，中文回退到加载的字体
      _sysFontFamily = loadLatin
          ? _sysSansFamily
          : loadCjk
          ? 'sans-serif'
          : null;
      _sysFontFamilyFallback = loadCjk ? const [_sysCjkFamily] : null;
    } catch (e) {
      if (kDebugMode) debugPrint('syncSystemFont: $e');
    }
  }

  /// 系统正在使用、但本应用读不到文件的字体文件名（Android 10+）。
  ///
  /// 非空说明字体模块对本应用没有挂载（KernelSU/Magisk「卸载模块」），
  /// 这种情况下应用里拿不到字体数据，只能提示用户去 root 管理器里关掉。
  static List<String>? hiddenSystemFonts() {
    if (!Platform.isAndroid) return null;
    try {
      final array = AndroidHelper.hiddenSystemFonts();
      if (array == null) return null;
      try {
        final length = array.length;
        return [
          for (var i = 0; i < length; i++)
            ?array[i]?.toDartString(releaseOriginal: true),
        ];
      } finally {
        array.release();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('hiddenSystemFonts: $e');
      return null;
    }
  }

  static String _fontKey(_SysFont font) =>
      '${path.basename(font.path)}#${font.index}';

  static ({Map<int, _SysFont> latin, Map<int, _SysFont> cjk})?
  _querySystemFonts() {
    final array = AndroidHelper.systemDefaultFonts();
    if (array == null) return null;
    final latin = <int, _SysFont>{};
    final cjk = <int, _SysFont>{};
    try {
      final length = array.length;
      for (var i = 0; i < length; i++) {
        final item = array[i]?.toDartString(releaseOriginal: true);
        if (item == null) continue;
        // script|weight|ttcIndex|path
        final parts = item.split('|');
        if (parts.length < 4) continue;
        final weight = int.tryParse(parts[1]);
        final index = int.tryParse(parts[2]);
        if (weight == null || index == null) continue;
        final font = (path: parts.sublist(3).join('|'), index: index);
        (parts[0] == 'cjk' ? cjk : latin)[weight] = font;
      }
    } finally {
      array.release();
    }
    if (latin.isEmpty && cjk.isEmpty) return null;
    return (latin: latin, cjk: cjk);
  }

  /// Flutter（Skia）实际会用的字体：fonts.xml 中 sans-serif 族（默认族），
  /// 以及第一个 lang 以 zh 开头的回退族（应用语言为 zh-CN）
  static Future<({Set<String>? latin, Set<String>? cjk})?>
  _readFontsXml() async {
    String xml;
    try {
      xml = await File('/system/etc/fonts.xml').readAsString();
    } catch (_) {
      return null;
    }
    xml = xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final familyRe = RegExp(r'<family\b([^>]*)>(.*?)</family>', dotAll: true);
    final fontRe = RegExp(r'<font\b([^>]*)>\s*([^<\s]+)');
    final indexRe = RegExp(r'\bindex\s*=\s*"(\d+)"');
    final nameRe = RegExp(r'\bname\s*=\s*"([^"]*)"');
    final langRe = RegExp(r'\blang\s*=\s*"([^"]*)"');
    final langSplit = RegExp(r'[\s,]+');

    Set<String>? latin;
    Set<String>? cjk;
    for (final family in familyRe.allMatches(xml)) {
      final attrs = family.group(1)!;
      Set<String> files() => {
        for (final font in fontRe.allMatches(family.group(2)!))
          '${path.basename(font.group(2)!)}'
              '#${indexRe.firstMatch(font.group(1)!)?.group(1) ?? '0'}',
      };
      final name = nameRe.firstMatch(attrs)?.group(1);
      if (name != null) {
        if (latin == null && name == 'sans-serif') latin = files();
      } else if (cjk == null) {
        final lang = langRe.firstMatch(attrs)?.group(1);
        if (lang != null &&
            lang.split(langSplit).any((e) => e.startsWith('zh'))) {
          cjk = files();
        }
      }
      if (latin != null && cjk != null) break;
    }
    return (latin: latin, cjk: cjk);
  }

  static Future<bool> _loadSysFonts(Set<_SysFont> fonts, String family) async {
    bool loaded = false;
    for (final font in fonts) {
      final id = '$family|${font.path}';
      if (_loadedSysFonts.contains(id)) {
        loaded = true;
        continue;
      }
      try {
        final bytes = await File(font.path).readAsBytes();
        await loadFontFromList(bytes, fontFamily: family);
        _loadedSysFonts.add(id);
        loaded = true;
      } catch (e) {
        if (kDebugMode) debugPrint('load system font ${font.path}: $e');
      }
    }
    return loaded;
  }

  @pragma('vm:notify-debugger-on-exception')
  static Future<void> _readAndLoad() async {
    try {
      final bytes = await fontFile.readAsBytes();
      await _loadFont(bytes, fontFamily: fontFamily!);
    } catch (_) {}
  }

  static void removeFontIfExists() {
    if (fontFile.existsSync()) {
      fontFile.delete();
    }
  }

  @pragma('vm:notify-debugger-on-exception')
  static Future<void> _loadFont(
    Uint8List bytes, {
    required String fontFamily,
  }) async {
    try {
      await loadFontFromList(bytes, fontFamily: fontFamily);
    } catch (_) {}
  }

  @pragma('vm:notify-debugger-on-exception')
  static Future<Map<String, Uint8List>?> pickFonts() async {
    try {
      final files = await FilePicker.pickFiles(
        type: .custom,
        allowedExtensions: _kFontExts,
      );
      if (files.isNotEmpty) {
        final Map<String, Uint8List> fonts = {};
        final now = DateTime.now().millisecondsSinceEpoch.toString();

        Future<void> loadFont(file) async {
          final name = '$now/${path.basenameWithoutExtension(file.name)}';
          final bytes = await file.readAsBytes();
          await _loadFont(bytes, fontFamily: name);
          fonts[name] = bytes;
        }

        await Future.wait(files.map(loadFont));
        return fonts;
      }
    } catch (_) {
      if (kDebugMode) rethrow;
    }
    return null;
  }

  static Set<String> getFont() {
    if (_initialized) return _fonts;
    _initialized = true;
    if (!switch (defaultTargetPlatform) {
      .android => _initAndroid(),
      .windows => _initWindows(),
      .linux => _initLinux(),
      _ => true,
    }) {
      // TODO: ios/macos CTFontManagerCopyAvailableFontFamilyNames
      SmartDialog.showToast('加载系统字体失败');
    }
    return _fonts;
  }

  static int _enumFontCallback(
    Pointer<LOGFONT> lpelfe,
    Pointer<TEXTMETRIC> lpntme,
    int fontType,
    int lParam,
  ) {
    final familyName = lpelfe.ref.lfFaceName;
    if (familyName.startsWith('@')) return 1;
    _fonts.add(lpelfe.ref.lfFaceName);
    return 1;
  }

  @pragma('vm:prefer-inline')
  static bool _initWindows() {
    final hdc = GetDC(null);

    final logfont = calloc<LOGFONT>();
    logfont.ref.lfCharSet = DEFAULT_CHARSET;
    logfont.ref.lfFaceName = '';

    try {
      final result = EnumFontFamiliesEx(
        hdc,
        logfont,
        Pointer.fromFunction(_enumFontCallback, 0),
        const LPARAM(0),
        0,
      );

      return result != 0;
    } finally {
      calloc.free(logfont);
      ReleaseDC(null, hdc);
    }
  }

  @pragma('vm:prefer-inline')
  static bool _initLinux() {
    final FontConfig fc;
    try {
      fc = FontConfig(DynamicLibrary.open('libfontconfig.so.1'));
    } catch (e) {
      if (kDebugMode) debugPrint('无法加载 Fontconfig 库: $e');
      return false;
    }

    final config = fc.FcInitLoadConfigAndFonts();
    if (config == nullptr) {
      if (kDebugMode) debugPrint('Fontconfig 初始化失败');
      return false;
    }

    final fontSet = fc.FcConfigGetFonts(config, FcSetName.FcSetSystem);
    if (fontSet == nullptr) {
      if (kDebugMode) debugPrint('无法获取系统字体集');
      fc.FcConfigDestroy(config);
      return false;
    }

    final nfont = fontSet.ref.nfont;
    final family = FC_FAMILY.toNativeUtf8().cast<Char>();
    for (int i = 0; i < nfont; i++) {
      final pattern = fontSet.ref.fonts[i];
      if (pattern == nullptr) continue;

      final outPtr = calloc<Pointer<UnsignedChar>>();

      try {
        final result = fc.FcPatternGetString(pattern, family, 0, outPtr);

        if (result == 0) {
          final strPtr = outPtr.value;
          if (strPtr != nullptr) {
            _fonts.add(strPtr.cast<Utf8>().toDartString());
          }
        }
      } finally {
        calloc.free(outPtr);
      }
    }
    calloc.free(family);
    fc.FcConfigDestroy(config);

    return true;
  }

  @pragma('vm:prefer-inline')
  static bool _initAndroid() {
    final fontFamilies = AndroidHelper.fontFamilies();
    if (fontFamilies != null) {
      try {
        final length = fontFamilies.length;
        for (var i = 0; i < length; i++) {
          _fonts.add(fontFamilies[i]!.toDartString(releaseOriginal: true));
        }
        return true;
      } finally {
        fontFamilies.release();
      }
    }
    return false;
  }
}
