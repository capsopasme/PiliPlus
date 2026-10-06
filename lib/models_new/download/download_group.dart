/// 离线缓存的手动分组。
///
/// 保存在下载目录下的 [DownloadService] 分组文件里，与缓存文件放在一起：
/// 重装应用或清除数据后，只要缓存还在，分组也还在。
class DownloadGroup {
  DownloadGroup({
    required this.id,
    required this.name,
    List<String>? keys,
  }) : keys = keys ?? <String>[];

  final String id;
  String name;

  /// 组内条目的 [DownloadSeasonInfo.groupKey]
  final List<String> keys;

  factory DownloadGroup.fromJson(Map<String, dynamic> json) => DownloadGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    keys: (json['keys'] as List?)?.whereType<String>().toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'keys': keys,
  };
}
