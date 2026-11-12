// Small key-value store for state that belongs to this device rather than
// to the user's data: the login session and cloud-backup bookkeeping. It is
// kept out of the database so it never travels inside a backup.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class DeviceStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemoryDeviceStore implements DeviceStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class FileDeviceStore implements DeviceStore {
  FileDeviceStore([Future<File> Function()? locate])
      : _locate = locate ?? _defaultFile;

  final Future<File> Function() _locate;
  Map<String, String>? _cache;

  static Future<File> _defaultFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'device_state.json'));
  }

  Future<Map<String, String>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    var values = <String, String>{};
    try {
      final file = await _locate();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        values = (decoded as Map).map((k, v) => MapEntry('$k', '$v'));
      }
    } on FormatException {
      // A truncated file is treated as empty: the user just logs in again.
    }
    return _cache = values;
  }

  Future<void> _save(Map<String, String> values) async {
    final file = await _locate();
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(values), flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String value) async {
    final values = await _load();
    values[key] = value;
    await _save(values);
  }

  @override
  Future<void> delete(String key) async {
    final values = await _load();
    if (values.remove(key) != null) await _save(values);
  }
}

final deviceStoreProvider = Provider<DeviceStore>((ref) => FileDeviceStore());
