import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PreparedAppUpdate {
  const PreparedAppUpdate({
    required this.version,
    required this.installer,
  });

  final String version;
  final File installer;
}

/// Downloads a release installer before asking the user to restart.
///
/// At the moment only Windows can be updated safely without an app store: the
/// signed/unsigned Inno installer already knows the previous install directory,
/// stops Delore and replaces the application atomically. Other platforms keep
/// the existing GitHub download flow until their native signing/install path is
/// available.
class AppUpdater {
  Future<PreparedAppUpdate?>? _preparing;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 20),
      headers: const {'User-Agent': 'Delore updater'},
    ),
  );

  Future<PreparedAppUpdate?> prepare(Map<String, dynamic> release) {
    return _preparing ??= _prepare(release).whenComplete(() {
      _preparing = null;
    });
  }

  Future<PreparedAppUpdate?> _prepare(
    Map<String, dynamic> release,
  ) async {
    if (!Platform.isWindows) return null;

    final version = (release['tag_name'] as String? ?? '').trim();
    final assets = release['assets'];
    if (version.isEmpty || assets is! List) return null;

    final architecture = Abi.current() == Abi.windowsArm64 ? 'arm64' : 'amd64';
    final expectedName = 'Delore-windows-$architecture-setup.exe';
    Map<String, dynamic>? asset;
    Map<String, dynamic>? checksumAsset;
    for (final candidate in assets) {
      if (candidate is Map) {
        if (candidate['name'] == expectedName) {
          asset = Map<String, dynamic>.from(candidate);
        } else if (candidate['name'] == '$expectedName.sha256') {
          checksumAsset = Map<String, dynamic>.from(candidate);
        }
      }
    }
    if (asset == null) return null;

    final url = asset['browser_download_url'] as String?;
    final expectedSize = asset['size'] as int? ?? 0;
    if (url == null || url.isEmpty) return null;
    final expectedHash = await _loadExpectedHash(checksumAsset);

    final temporary = await getTemporaryDirectory();
    final updateRoot = Directory(p.join(temporary.path, 'Delore', 'updates'));
    final releaseDirectory = Directory(
      p.join(
          updateRoot.path, version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_')),
    );
    await releaseDirectory.create(recursive: true);
    await _discardOldDownloads(updateRoot, keep: releaseDirectory.path);

    final installer = File(p.join(releaseDirectory.path, expectedName));
    if (await _isComplete(installer, expectedSize, expectedHash)) {
      return PreparedAppUpdate(version: version, installer: installer);
    }

    final partial = File('${installer.path}.part');
    if (await partial.exists()) await partial.delete();
    await _dio.download(
      url,
      partial.path,
      deleteOnError: true,
      options: Options(
        followRedirects: true,
        maxRedirects: 5,
        headers: const {'Accept': 'application/octet-stream'},
      ),
    );
    if (!await _isComplete(partial, expectedSize, expectedHash)) {
      if (await partial.exists()) await partial.delete();
      throw const FileSystemException('Downloaded update is incomplete');
    }
    if (await installer.exists()) await installer.delete();
    await partial.rename(installer.path);
    return PreparedAppUpdate(version: version, installer: installer);
  }

  Future<bool> install(
    PreparedAppUpdate update, {
    required bool Function(String executable, String arguments) launchElevated,
  }) async {
    if (!Platform.isWindows || !await update.installer.exists()) return false;
    return launchElevated(
      update.installer.path,
      '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /RESTARTAPP',
    );
  }

  Future<String?> _loadExpectedHash(Map<String, dynamic>? asset) async {
    final url = asset?['browser_download_url'] as String?;
    if (url == null || url.isEmpty) return null;
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return RegExp(r'\b[a-fA-F0-9]{64}\b')
          .firstMatch(response.data ?? '')
          ?.group(0)
          ?.toLowerCase();
    } catch (e) {
      developer.log('Could not fetch update checksum: $e', name: 'AppUpdater');
      return null;
    }
  }

  Future<bool> _isComplete(
    File file,
    int expectedSize,
    String? expectedHash,
  ) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (expectedSize > 0 && length != expectedSize) return false;
    if (length == 0) return false;
    if (expectedHash == null) return true;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == expectedHash;
  }

  Future<void> _discardOldDownloads(
    Directory root, {
    required String keep,
  }) async {
    if (!await root.exists()) return;
    try {
      await for (final entry in root.list()) {
        if (entry is Directory &&
            p.normalize(entry.path) != p.normalize(keep)) {
          await entry.delete(recursive: true);
        }
      }
    } catch (e) {
      developer.log('Could not clean old app updates: $e', name: 'AppUpdater');
    }
  }
}

final appUpdater = AppUpdater();
