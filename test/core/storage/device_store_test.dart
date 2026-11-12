import 'dart:io';

import 'package:carjobfinance/core/storage/device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('device_store_test');
    file = File(p.join(dir.path, 'device_state.json'));
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  test('values written by one store are read by a new store', () async {
    final first = FileDeviceStore(() async => file);
    await first.write('auth_session', '{"token":"abc"}');

    final second = FileDeviceStore(() async => file);
    expect(await second.read('auth_session'), '{"token":"abc"}');
  });

  test('delete removes the value from disk', () async {
    final store = FileDeviceStore(() async => file);
    await store.write('data_owner_id', 'user-1');
    await store.delete('data_owner_id');

    final reopened = FileDeviceStore(() async => file);
    expect(await reopened.read('data_owner_id'), isNull);
  });

  test('a truncated file is treated as empty', () async {
    await file.writeAsString('{"auth_session": "ab');

    final store = FileDeviceStore(() async => file);
    expect(await store.read('auth_session'), isNull);
  });

  test('a missing file reads as empty', () async {
    final store = FileDeviceStore(() async => file);
    expect(await store.read('anything'), isNull);
  });
}
