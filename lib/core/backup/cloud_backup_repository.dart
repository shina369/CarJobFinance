// Remote copy of the user's full backup: one row per account, protected by
// row-level security so an account can only reach its own row.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

import '../auth/supabase_auth_repository.dart';

abstract class CloudBackupRepository {
  /// When the account's backup was last uploaded; null if there is none.
  Future<DateTime?> lastBackupAt();

  /// Replaces the account's backup with [backupJson].
  Future<DateTime> upload(String backupJson);

  /// The backup JSON, or null if the account has none.
  Future<String?> download();
}

class SupabaseCloudBackupRepository implements CloudBackupRepository {
  SupabaseCloudBackupRepository(this._client, this._ensureSession);

  static const String table = 'backups';

  final SupabaseClient _client;
  final Future<void> Function() _ensureSession;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('No signed-in user');
    return id;
  }

  @override
  Future<DateTime?> lastBackupAt() async {
    await _ensureSession();
    final row = await _client
        .from(table)
        .select('updated_at')
        .eq('user_id', _userId)
        .maybeSingle();
    return row == null ? null : DateTime.parse(row['updated_at'] as String);
  }

  @override
  Future<DateTime> upload(String backupJson) async {
    await _ensureSession();
    final now = DateTime.now().toUtc();
    await _client.from(table).upsert({
      'user_id': _userId,
      'content': jsonDecode(backupJson),
      'updated_at': now.toIso8601String(),
    });
    return now;
  }

  @override
  Future<String?> download() async {
    await _ensureSession();
    final row = await _client
        .from(table)
        .select('content')
        .eq('user_id', _userId)
        .maybeSingle();
    return row == null ? null : jsonEncode(row['content']);
  }
}

final cloudBackupRepositoryProvider = Provider<CloudBackupRepository>(
  (ref) => SupabaseCloudBackupRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(authRepositoryProvider).ensureOnlineSession,
  ),
);
