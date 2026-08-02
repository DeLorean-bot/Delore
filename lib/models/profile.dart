// ignore_for_file: invalid_annotation_target
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flclashx/clash/core.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/utils/device_info_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'clash_config.dart';

part 'generated/profile.freezed.dart';
part 'generated/profile.g.dart';

typedef SelectedMap = Map<String, String>;

@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int total,
    @Default(0) int expire,
  }) = _SubscriptionInfo;

  factory SubscriptionInfo.fromJson(Map<String, Object?> json) =>
      _$SubscriptionInfoFromJson(json);

  factory SubscriptionInfo.formHString(String? info) {
    if (info == null) return const SubscriptionInfo();
    final list = info.split(";");
    final map = <String, int?>{};
    for (final i in list) {
      final keyValue = i.trim().split("=");
      if (keyValue.length < 2) continue;
      map[keyValue[0]] = int.tryParse(keyValue[1]);
    }
    return SubscriptionInfo(
      upload: map["upload"] ?? 0,
      download: map["download"] ?? 0,
      total: map["total"] ?? 0,
      expire: map["expire"] ?? 0,
    );
  }
}

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    String? label,
    String? currentGroupName,
    @Default("") String url,
    DateTime? lastUpdateDate,
    required Duration autoUpdateDuration,
    SubscriptionInfo? subscriptionInfo,
    @Default(true) bool autoUpdate,
    @Default({}) SelectedMap selectedMap,
    @Default({}) Set<String> unfoldSet,
    @Default(OverrideData()) OverrideData overrideData,
    @JsonKey(includeToJson: false, includeFromJson: false)
    @Default(false)
    bool isUpdating,
    @Default({}) Map<String, String> providerHeaders,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);

  factory Profile.normal({
    String? label,
    String url = '',
  }) =>
      Profile(
        label: label,
        url: url,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        autoUpdateDuration: defaultUpdateDuration,
      );
}

@freezed
class OverrideData with _$OverrideData {
  const factory OverrideData({
    @Default(false) bool enable,
    @Default(OverrideRule()) OverrideRule rule,
  }) = _OverrideData;

  factory OverrideData.fromJson(Map<String, Object?> json) =>
      _$OverrideDataFromJson(json);
}

extension OverrideDataExt on OverrideData {
  List<String> get runningRule {
    if (!enable) {
      return [];
    }
    return rule.rules.map((item) => item.value).toList();
  }
}

@freezed
class OverrideRule with _$OverrideRule {
  const factory OverrideRule({
    @Default(OverrideRuleType.added) OverrideRuleType type,
    @Default([]) List<Rule> overrideRules,
    @Default([]) List<Rule> addedRules,
  }) = _OverrideRule;

  factory OverrideRule.fromJson(Map<String, Object?> json) =>
      _$OverrideRuleFromJson(json);
}

extension OverrideRuleExt on OverrideRule {
  List<Rule> get rules => switch (type == OverrideRuleType.override) {
        true => overrideRules,
        false => addedRules,
      };

  OverrideRule updateRules(List<Rule> Function(List<Rule> rules) builder) {
    if (type == OverrideRuleType.added) {
      return copyWith(addedRules: builder(addedRules));
    }
    return copyWith(overrideRules: builder(overrideRules));
  }
}

extension ProfilesExt on List<Profile> {
  Profile? getProfile(String? profileId) {
    final index = indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : this[index];
  }
}

extension ProfileExtension on Profile {
  static const _maxStoredRevisions = 5;

  ProfileType get type =>
      url.isEmpty == true ? ProfileType.file : ProfileType.url;

  bool get realAutoUpdate => url.isEmpty == true ? false : autoUpdate;

  Future<void> checkAndUpdate() async {
    final isExists = await check();
    if (!isExists) {
      if (url.isNotEmpty && realAutoUpdate) {
        await update();
      }
    }
  }

  Future<bool> check() async {
    final profilePath = await appPath.getProfilePath(id);
    return File(profilePath).exists();
  }

  Future<File> getFile() async {
    final path = await appPath.getProfilePath(id);
    final file = File(path);
    final isExists = await file.exists();
    if (!isExists) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<int> get profileLastModified async {
    final file = await getFile();
    return (await file.lastModified()).microsecondsSinceEpoch;
  }

  Future<Profile> update({
    bool shouldSendHeaders = true,
    bool useProxy = false,
  }) async {
    final headers = <String, dynamic>{};

    if (shouldSendHeaders) {
      final deviceInfoService = DeviceInfoService();
      final details = await deviceInfoService.getDeviceDetails();

      if (details.hwid != null) headers['x-hwid'] = details.hwid;
      if (details.os != null) headers['x-device-os'] = details.os;
      if (details.osVersion != null) headers['x-ver-os'] = details.osVersion;
      if (details.model != null) headers['x-device-model'] = details.model;
    }

    final response = await request.getFileResponseForUrl(
      url,
      headers: headers.isNotEmpty ? headers : null,
      useProxy: useProxy,
    );

    final disposition = response.headers.value("content-disposition");
    final userinfo = response.headers.value('subscription-userinfo');

    final responseData = response.data;
    if (responseData == null) {
      throw Exception("Failed to get profile data from response.");
    }

    final providerHeaders = <String, String>{};

    final headersToCollect = [
      'announce',
      'support-url',
      'profile-update-interval',
      'x-hwid-max-devices-reached',
      'x-hwid-not-supported',
    ];

    for (final headerName in headersToCollect) {
      final value = response.headers.value(headerName);
      if (value != null && value.isNotEmpty) {
        providerHeaders[headerName] = value;
      }
    }

    response.headers.forEach((name, values) {
      if (name.toLowerCase().startsWith('flclashx-') && values.isNotEmpty) {
        providerHeaders[name.toLowerCase()] = values.first;
      }
    });

    Duration? durationFromHeader;
    final updateIntervalHeader = providerHeaders['profile-update-interval'];
    if (updateIntervalHeader != null) {
      final hours = int.tryParse(updateIntervalHeader);
      if (hours != null && hours > 0) {
        durationFromHeader = Duration(hours: hours);
      }
    }

    String updatedUrl = url;
    final newDomain = providerHeaders['flclashx-newdomain'];
    if (newDomain != null && newDomain.isNotEmpty) {
      final currentUri = Uri.tryParse(url);
      if (currentUri != null && currentUri.host != newDomain) {
        updatedUrl = currentUri.replace(host: newDomain).toString();
      }
    }

    return copyWith(
      url: updatedUrl,
      label: label ?? utils.getFileNameForDisposition(disposition) ?? id,
      subscriptionInfo: SubscriptionInfo.formHString(userinfo),
      autoUpdateDuration: durationFromHeader ?? autoUpdateDuration,
      providerHeaders: providerHeaders,
    ).saveFile(responseData);
  }

  Future<Profile> saveFile(Uint8List bytes) async {
    final message = await clashCore.validateConfig(utf8.decode(bytes));
    if (message.isNotEmpty) {
      throw message;
    }
    await _replaceProfileFile(bytes);
    return copyWith(lastUpdateDate: DateTime.now());
  }

  Future<Profile> saveFileWithString(String value) async {
    final message = await clashCore.validateConfig(value);
    if (message.isNotEmpty) {
      throw message;
    }
    await _replaceProfileFile(utf8.encode(value));
    return copyWith(lastUpdateDate: DateTime.now());
  }

  /// Replaces a profile only after it has been validated by mihomo. The old
  /// file is moved out of the way first and restored if the final rename fails,
  /// so a power loss or an I/O error cannot leave a half-written subscription.
  Future<void> _replaceProfileFile(List<int> bytes) async {
    final profilePath = await appPath.getProfilePath(id);
    final file = File(profilePath);
    await file.parent.create(recursive: true);

    final nonce = DateTime.now().microsecondsSinceEpoch;
    final temporary = File('$profilePath.$nonce.pending');
    final rollback = File('$profilePath.$nonce.rollback');
    await temporary.writeAsBytes(bytes, flush: true);

    final hadPrevious = await file.exists() && await file.length() > 0;
    if (hadPrevious) {
      await _storeRevision(file, nonce);
      await file.rename(rollback.path);
    }

    try {
      await temporary.rename(profilePath);
      if (await rollback.exists()) await rollback.delete();
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (await rollback.exists()) {
        if (await file.exists()) await file.delete();
        await rollback.rename(profilePath);
      }
      rethrow;
    }
  }

  Future<Directory> get _revisionDirectory async {
    final profilePath = await appPath.getProfilePath(id);
    return Directory('$profilePath.revisions');
  }

  Future<void> _storeRevision(File source, int nonce) async {
    final directory = await _revisionDirectory;
    await directory.create(recursive: true);
    await source.copy('${directory.path}/$nonce.yaml');

    final revisions = await directory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.yaml'))
        .cast<File>()
        .toList();
    revisions.sort((a, b) => b.path.compareTo(a.path));
    for (final stale in revisions.skip(_maxStoredRevisions)) {
      await stale.delete();
    }
  }

  /// Newest first. These are known-good files because revisions are only
  /// created after both download and mihomo validation have succeeded.
  Future<List<File>> getRevisions() async {
    final directory = await _revisionDirectory;
    if (!await directory.exists()) return const [];
    final revisions = await directory
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.yaml'))
        .cast<File>()
        .toList();
    revisions.sort((a, b) => b.path.compareTo(a.path));
    return revisions;
  }

  Future<Profile> restoreRevision(File revision) async {
    final bytes = await revision.readAsBytes();
    final message = await clashCore.validateConfig(utf8.decode(bytes));
    if (message.isNotEmpty) throw message;
    await _replaceProfileFile(bytes);
    return copyWith(lastUpdateDate: DateTime.now());
  }
}
