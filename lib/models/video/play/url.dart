import 'dart:math' show max, min;

import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models_new/sponsor_block/segment_item.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class PlayUrlModel {
  PlayUrlModel({
    this.from,
    this.result,
    this.message,
    this.quality,
    this.format,
    this.timeLength,
    this.acceptFormat,
    this.acceptDesc,
    this.acceptQuality,
    this.videoCodecid,
    this.seekParam,
    this.seekType,
    this.dash,
    this.supportFormats,
    this._lastPlayTime = 0,
    this.lastPlayCid,
  });

  String? from;
  String? result;
  String? message;
  int? quality;
  String? format;
  int? timeLength;
  String? acceptFormat;
  List<dynamic>? acceptDesc;
  List<int>? acceptQuality;
  int? videoCodecid;
  String? seekParam;
  String? seekType;
  Dash? dash;
  List<Durl>? durl;
  List<FormatItem>? supportFormats;
  Volume? volume;

  late int _lastPlayTime;
  int get lastPlayTime => _lastPlayTime;
  set lastPlayTime(int? value) {
    if (value != null && value > 0) {
      _lastPlayTime = value;
    } else {
      _lastPlayTime = 0;
    }
  }

  int? lastPlayCid;
  String? curLanguage;
  Language? language;
  List<SegmentItemModel>? clipInfoList;

  int findAvailableVideoQuality(int preferredQuality) {
    final curHighestVideoQa = dash!.video!.first.quality.code;
    if (acceptQuality case final qualitys?
        when preferredQuality <= curHighestVideoQa) {
      return qualitys.findClosestTarget((e) => e <= preferredQuality, max);
    } else {
      return curHighestVideoQa;
    }
  }

  @pragma('vm:notify-debugger-on-exception')
  int get missingVideoQualityBelowHighest {
    int best = -1;
    try {
      final video = dash!.video!;
      final available = video.availableVideoQualities;
      final highest = video.first.id;

      for (final item in supportFormats!) {
        final quality = item.quality;
        if (quality != null &&
            best < quality &&
            quality < highest &&
            !available.contains(quality)) {
          best = quality;
        }
      }
    } catch (_) {}
    return best;
  }

  PlayUrlModel.fromJson(Map<String, dynamic> json) {
    from = json['from'];
    result = json['result'];
    message = json['message'];
    quality = json['quality'];
    format = json['format'];
    timeLength = json['timelength'];
    acceptFormat = json['accept_format'];
    acceptDesc = json['accept_description'];
    acceptQuality = (json['accept_quality'] as List?)
        ?.map<int>((e) => e as int)
        .toList();
    videoCodecid = json['video_codecid'];
    seekParam = json['seek_param'];
    seekType = json['seek_type'];
    dash = json['dash'] != null ? Dash.fromJson(json['dash']) : null;
    durl = (json['durl'] as List?)?.map<Durl>((e) => Durl.fromJson(e)).toList();
    supportFormats = (json['support_formats'] as List?)
        ?.map<FormatItem>((e) => FormatItem.fromJson(e))
        .toList();
    volume = json['volume'] == null ? null : Volume.fromJson(json['volume']);
    lastPlayTime = json['last_play_time'];
    lastPlayCid = json['last_play_cid'];
    curLanguage = json['cur_language'];
    language = json['language'] == null
        ? null
        : Language.fromJson(json['language']);
    // debug
    // final clipInfoList = [
    //   {
    //     "start": 0,
    //     "end": 150,
    //     "clipType": "CLIP_TYPE_OP",
    //   },
    //   {
    //     "start": timeLength! ~/ 1000 - 150,
    //     "end": timeLength! ~/ 1000,
    //     "clipType": "CLIP_TYPE_ED",
    //   },
    // ];
    try {
      final List? clipInfoList = json['clip_info_list'];
      if (clipInfoList != null && clipInfoList.isNotEmpty) {
        this.clipInfoList = clipInfoList
            .map((e) => SegmentItemModel.fromPgcJson(e, timeLength))
            .toList();
      }
    } catch (_) {
      if (kDebugMode) rethrow;
    }
  }
}

class Language {
  Language({
    this.support,
    this.items,
  });

  bool? support;
  List<LanguageItem>? items;

  Language.fromJson(Map<String, dynamic> json) {
    support = json['support'];
    items =
        (json['items'] as List?)?.map((e) => LanguageItem.fromJson(e)).toList()
          ?..sort(_sort);
  }
}

int _sort(LanguageItem a, LanguageItem b) {
  final aHasZh = a.lang?.contains('zh') ?? false;
  final bHasZh = b.lang?.contains('zh') ?? false;
  if (aHasZh != bHasZh) return aHasZh ? -1 : 1;
  if (a.isAi != b.isAi) return a.isAi ? 1 : -1;
  return 0;
}

class LanguageItem {
  LanguageItem({
    this.lang,
    this.title,
    this.subtitleLang,
  });

  String? lang;
  String? title;
  String? subtitleLang;
  bool isAi = false;

  LanguageItem.fromJson(Map<String, dynamic> json) {
    lang = json['lang'];
    isAi = json['production_type'] == 2;
    title = '${json['title']}${isAi ? '（AI）' : ''}';
    subtitleLang = json['subtitle_lang'];
  }
}

class Dash {
  Dash({
    this.duration,
    this.minBufferTime,
    this.video,
    this.audio,
  });

  int? duration;
  double? minBufferTime;
  List<VideoItem>? video;
  List<AudioItem>? audio;

  Dash.fromJson(Map<String, dynamic> json) {
    duration = json['duration'];
    minBufferTime = json['minBufferTime'];
    video = (json['video'] as List?)
        ?.map<VideoItem>((e) => VideoItem.fromJson(e))
        .toList();
    final audio = [
      if (json['flac']?['audio'] case Map<String, dynamic> flac)
        AudioItem.fromJson(flac),
      if (json['dolby']?['audio'] case List list)
        ...list.map((e) => AudioItem.fromJson(e)),
      if (json['audio'] case List list)
        ...list.map((e) => AudioItem.fromJson(e)),
    ];
    this.audio = audio.isEmpty ? null : audio;
  }
}

class Durl {
  int? order;
  int? length;
  int? size;
  String? ahead;
  String? vhead;
  String? url;
  List<String>? backupUrl;

  Durl({
    this.order,
    this.length,
    this.size,
    this.ahead,
    this.vhead,
    this.url,
    this.backupUrl,
  });

  factory Durl.fromJson(Map<String, dynamic> json) {
    return Durl(
      order: json['order'],
      length: json['length'],
      size: json['size'],
      ahead: json['ahead'],
      vhead: json['vhead'],
      url: json['url'],
      backupUrl: (json['backup_url'] as List?)?.fromCast<String>(),
    );
  }

  Iterable<String> get playUrls sync* {
    if (url?.isNotEmpty == true) yield url!;
    if (backupUrl?.isNotEmpty == true) yield* backupUrl!;
  }
}

abstract class BaseItem {
  late int id;
  String? baseUrl;
  List<String>? backupUrl;
  int? bandWidth;
  String? mimeType;
  String? codecs;
  int? width;
  int? height;
  String? frameRate;
  String? sar;
  int? startWithSap;
  Map? segmentBase;
  int? codecid;

  BaseItem({
    required this.id,
    this.baseUrl,
    this.backupUrl,
    this.bandWidth,
    this.mimeType,
    this.codecs,
    this.width,
    this.height,
    this.frameRate,
    this.sar,
    this.startWithSap,
    this.segmentBase,
    this.codecid,
  });

  BaseItem.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    baseUrl = json['baseUrl'] ?? json['base_url'];
    backupUrl = ((json['backupUrl'] ?? json['backup_url']) as List?)
        ?.fromCast<String>();
    bandWidth = json['bandWidth'] ?? json['bandwidth'];
    mimeType = json['mime_type'];
    codecs = json['codecs'];
    width = json['width'];
    height = json['height'];
    frameRate = json['frameRate'] ?? json['frame_rate'];
    sar = json['sar'];
    startWithSap = json['startWithSap'] ?? json['start_with_sap'];
    segmentBase = json['segmentBase'] ?? json['segment_base'];
    codecid = json['codecid'];
  }

  Iterable<String> get playUrls sync* {
    if (baseUrl?.isNotEmpty == true) yield baseUrl!;
    if (backupUrl?.isNotEmpty == true) yield* backupUrl!;
  }
}

class VideoItem extends BaseItem {
  late VideoQuality quality;

  VideoItem({
    required super.id,
    super.baseUrl,
    super.backupUrl,
    super.bandWidth,
    super.mimeType,
    super.codecs,
    super.width,
    super.height,
    super.frameRate,
    super.sar,
    super.startWithSap,
    super.segmentBase,
    super.codecid,
    required this.quality,
  });

  VideoItem.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    quality = VideoQuality.fromCode(json['id']);
  }
}

class AudioItem extends BaseItem {
  late String quality;

  AudioItem.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    quality = AudioQuality.fromCode(json['id']).desc;
  }
}

extension BaseItemExt<T extends BaseItem> on List<T> {
  void merge(List<T>? other) {
    if (other == null) return;
    final keys = {for (final item in this) (item.id, item.codecid)};
    for (final item in other) {
      if (keys.add((item.id, item.codecid))) {
        add(item);
      }
    }
    sort((a, b) => b.id.compareTo(a.id));
  }

  Set<int> get availableVideoQualities => map((i) => i.id).toSet();
}

class FormatItem {
  FormatItem({
    this.quality,
    this.format,
    this.newDesc,
    this.displayDesc,
    this.codecs,
  });

  int? quality;
  String? format;
  String? newDesc;
  String? displayDesc;
  List<String>? codecs;

  FormatItem.fromJson(Map<String, dynamic> json) {
    quality = json['quality'];
    format = json['format'];
    newDesc = json['new_description'];
    displayDesc = json['display_desc'];
    codecs = (json['codecs'] as List?)?.fromCast<String>();
  }
}

class Volume {
  Volume({
    required this.measuredI,
    required this.measuredLra,
    required this.measuredTp,
    required this.measuredThreshold,
    required this.targetOffset,
    required this.targetI,
    required this.targetTp,
    // required this.multiSceneArgs,
  });

  final num measuredI;
  final num measuredLra;
  final num measuredTp;
  final num measuredThreshold;
  final num targetOffset;
  final num targetI;
  final num targetTp;

  // final MultiSceneArgs? multiSceneArgs;

  factory Volume.fromJson(Map<String, dynamic> json) {
    return Volume(
      measuredI: json["measured_i"] ?? 0,
      measuredLra: json["measured_lra"] ?? 0,
      measuredTp: json["measured_tp"] ?? 0,
      measuredThreshold: json["measured_threshold"] ?? 0,
      targetOffset: json["target_offset"] ?? 0,
      targetI: json["target_i"] ?? 0,
      targetTp: json["target_tp"] ?? 0,
      // multiSceneArgs: json["multi_scene_args"] == null ? null : MultiSceneArgs.fromJson(json["multi_scene_args"]),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'measured_i': measuredI,
    'measured_lra': measuredLra,
    'measured_tp': measuredTp,
    'measured_threshold': measuredThreshold,
    'target_offset': targetOffset,
    'target_i': targetI,
    'target_tp': targetTp,
  };

  /// 音量均衡的目标响度（LUFS），与常见流媒体平台的 -14 ~ -16 一致
  static const double kTargetLoudness = -16;

  /// 增益后允许的最高真峰值（dBTP），留 1dB 余量防止削波
  static const double kMaxTruePeak = -1;

  static const double kMinGain = -20;

  /// 与 mpv 的 --volume-gain-max 默认值一致
  static const double kMaxGain = 12;

  /// 音量均衡的固定增益（dB），无有效测量值时为 null。
  ///
  /// 增益 = 目标响度 - 测得的整体响度，且不超过「真峰值余量」，
  /// 这样提升音量也不会削波，不需要压限器；没有可信的真峰值时只衰减不提升。
  double? get normalizationGain {
    final i = measuredI.toDouble();
    // 0（字段缺失时的默认值）或低于静音门限（-70）都不可信
    if (!i.isFinite || i >= 0 || i <= -70) return null;
    double gain = kTargetLoudness - i;
    final tp = measuredTp.toDouble();
    if (tp.isFinite && tp > -70 && tp < 10 && tp != 0) {
      gain = min(gain, kMaxTruePeak - tp);
    } else {
      gain = min(gain, 0.0);
    }
    gain = max(kMinGain, min(kMaxGain, gain));
    if (gain.abs() < 0.1) return null;
    return gain;
  }

  bool get isNotEmpty =>
      measuredI != 0 ||
      measuredLra != 0 ||
      measuredTp != 0 ||
      measuredThreshold != 0;
}
