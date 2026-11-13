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

  /// The exported file on disk.
  final File file;

  /// The raw bytes written to [file].
  final Uint8List bytes;

  /// Size of the file in bytes.
  int get sizeInBytes => bytes.length;
}

/// Persists and shares activity exports.
///
/// The exports never leave the device unless the user explicitly triggers the
/// system share sheet.
class ActivityExportService {
  /// Creates the service.
  ActivityExportService();

  /// MIME type used for Garmin FIT files.
  static const String fitMimeType = 'application/vnd.garmin.fit';

  /// Native channel that writes exports into the public Downloads folder.
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
  }) {
    return _saveFile(bytes, activityName: activityName, extension: 'png');
  }

  /// Writes the FIT bytes to the application documents directory.
  ///
  /// This private copy is used for sharing. The user-facing "Save FIT" action
  /// calls [saveFitToDownloads] instead, so the file is not hidden inside the
  /// app sandbox.
  Future<ExportResult> saveFit(
    Uint8List bytes, {
    required String activityName,
  }) {
    return _saveFile(bytes, activityName: activityName, extension: 'fit');
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
  }) {
    return _saveToDownloads(
      bytes,
      activityName: activityName,
      extension: 'png',
      mimeType: 'image/png',
      method: 'savePngToDownloads',
    );
  }

  /// Saves the FIT file into the device's public Downloads folder.
  ///
  /// Returns the user-visible location, for example
  /// `Downloads/morning_ride_1720000000000.fit`.
  Future<String> saveFitToDownloads(
    Uint8List bytes, {
    required String activityName,
  }) {
    return _saveToDownloads(
      bytes,
      activityName: activityName,
      extension: 'fit',
      mimeType: fitMimeType,
      method: 'saveFileToDownloads',
    );
  }

  /// Opens the native share sheet for the given PNG [file].
  ///
  /// [origin] is the screen rectangle of the button that triggered the share.
  /// It is required by iPadOS to anchor the popover.
  Future<ShareResult> sharePng(File file, {String? text, Rect? origin}) {
    return _shareFile(file, mimeType: 'image/png', text: text, origin: origin);
  }

  /// Opens the native share sheet for the given FIT [file].
  Future<ShareResult> shareFit(File file, {String? text, Rect? origin}) {
    return _shareFile(file, mimeType: fitMimeType, text: text, origin: origin);
  }

  /// Writes [bytes] to a timestamped file in the app sandbox.
  Future<ExportResult> _saveFile(
    Uint8List bytes, {
    required String activityName,
    required String extension,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(p.join(directory.path, 'exports'));
    if (!exportDirectory.existsSync()) {
      await exportDirectory.create(recursive: true);
    }

    final file = File(
      p.join(exportDirectory.path, _fileName(activityName, extension)),
    );
    await file.writeAsBytes(bytes, flush: true);

    return ExportResult(file: file, bytes: bytes);
  }

  /// Saves bytes into the device's public Downloads folder.
  Future<String> _saveToDownloads(
    Uint8List bytes, {
    required String activityName,
    required String extension,
    required String mimeType,
    required String method,
  }) async {
    final location = await _downloadsChannel.invokeMethod<String>(
      method,
      <String, Object?>{
        'fileName': _fileName(activityName, extension),
        'bytes': bytes,
        'mimeType': mimeType,
      },
    );
    if (location == null || location.isEmpty) {
      throw StateError('The file could not be saved to Downloads.');
    }
    return location;
  }

  /// Opens the native share sheet for [file].
  Future<ShareResult> _shareFile(
    File file, {
    required String mimeType,
    String? text,
    Rect? origin,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: mimeType)],
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

  /// Builds a collision-resistant, file-system safe export name.
  String _fileName(String activityName, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${_slug(activityName)}_$timestamp.$extension';
  }
}
