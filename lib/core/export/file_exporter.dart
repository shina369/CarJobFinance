// Hands generated files (CSV, PDF, backup) to the user and reads backup
// files back. Behind interfaces so pages can be tested without plugins.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

abstract class FileExporter {
  /// Delivers the file to the user. Returns false when the user cancelled.
  Future<bool> export({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });
}

abstract class BackupFilePicker {
  /// Lets the user choose a backup file and returns its text content,
  /// or null when the user cancelled.
  Future<String?> pickBackupContent();
}

/// Phones get the system share sheet (save to Files/Drive, send by e-mail or
/// messaging apps); desktop and web get a regular "Save as" dialog.
class PlatformFileExporter implements FileExporter {
  const PlatformFileExporter();

  bool get _useShareSheet =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> export({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (!_useShareSheet) {
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      return uri != null;
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}

class PlatformBackupFilePicker implements BackupFilePicker {
  const PlatformBackupFilePicker();

  @override
  Future<String?> pickBackupContent() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  }
}

final fileExporterProvider =
    Provider<FileExporter>((ref) => const PlatformFileExporter());

final backupFilePickerProvider =
    Provider<BackupFilePicker>((ref) => const PlatformBackupFilePicker());
