import 'dart:io';

import 'package:flutter/services.dart';
// `XFile` is provided by `cross_file`; the import is explicit on purpose even
// though `share_plus` re-exports it.
// ignore: unnecessary_import
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Result of an export operation.
class ExportResult {
  /// Creates an export result.
  const ExportResult({required this.file, required this.bytes});

  /// The PNG file on disk.
  final File file;

  /// The raw PNG bytes.
  final Uint8List bytes;

  /// Size of the file in bytes.
  int get sizeInBytes => bytes.length;
}

/// Persists and shares the transparent PNG export of an activity.
///
/// The export never leaves the device unless the user explicitly triggers the
/// system share sheet.
class ActivityExportService {
  /// Creates the service.
  ActivityExportService();

  /// Native channel that writes PNGs into the public Downloads folder.
  static const MethodChannel _downloadsChannel = MethodChannel(
    'com.previx.traincenter/downloads',
  );

  /// Writes the PNG bytes to the application documents directory.
  ///
  /// This private copy is used for sharing. The user-facing "Save PNG" action
  /// calls [savePngToDownloads] instead, so the exported image is not hidden
  /// inside the app sandbox.
  Future<ExportResult> savePng(
    Uint8List bytes, {
    required String activityName,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(p.join(directory.path, 'exports'));
    if (!exportDirectory.existsSync()) {
      await exportDirectory.create(recursive: true);
    }

    final file = File(p.join(exportDirectory.path, _fileName(activityName)));
    await file.writeAsBytes(bytes, flush: true);

    return ExportResult(file: file, bytes: bytes);
  }

  /// Saves the PNG into the device's public Downloads folder.
  ///
  /// Returns the user-visible location, for example
  /// `Downloads/traincenter_1720000000000.png`. Android 10+ publishes the
  /// image through MediaStore; Android 9 and older asks for storage permission
  /// on the first save.
  Future<String> savePngToDownloads(
    Uint8List bytes, {
    required String activityName,
  }) async {
    final location = await _downloadsChannel.invokeMethod<String>(
      'savePngToDownloads',
      <String, Object?>{'fileName': _fileName(activityName), 'bytes': bytes},
    );
    if (location == null || location.isEmpty) {
      throw StateError('The image could not be saved to Downloads.');
    }
    return location;
  }

  /// Opens the native share sheet for the given PNG [file].
  ///
  /// [origin] is the screen rectangle of the button that triggered the share.
  /// It is required by iPadOS to anchor the popover.
  Future<ShareResult> sharePng(File file, {String? text, Rect? origin}) {
    return SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'image/png')],
        text: text,
        title: 'Share activity',
        subject: 'TrainCenter activity',
        sharePositionOrigin: origin,
      ),
    );
  }

  /// Converts a title into a safe file name fragment.
  String _slug(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'activity' : slug;
  }

  /// Builds a collision-resistant, file-system safe PNG name.
  String _fileName(String activityName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${_slug(activityName)}_$timestamp.png';
  }
}
