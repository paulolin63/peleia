import 'dart:typed_data';

import 'history_thumb_store_stub.dart'
    if (dart.library.io) 'history_thumb_store_io.dart' as impl;

/// Persists history thumbnails outside SharedPreferences on IO platforms.
class HistoryThumbStore {
  static Future<String?> save(String entryId, Uint8List jpegBytes) =>
      impl.saveThumb(entryId, jpegBytes);

  static Future<Uint8List?> load(String? relativeName) =>
      impl.loadThumb(relativeName);

  static Future<void> delete(String? relativeName) =>
      impl.deleteThumb(relativeName);

  static Future<void> clearAll() => impl.clearThumbs();
}
