import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Directory> _dir() async {
  final root = await getApplicationSupportDirectory();
  final dir = Directory('${root.path}/history_thumbs');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String?> saveThumb(String entryId, Uint8List jpegBytes) async {
  final safe = entryId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final name = '$safe.jpg';
  final file = File('${(await _dir()).path}/$name');
  await file.writeAsBytes(jpegBytes, flush: true);
  return name;
}

Future<Uint8List?> loadThumb(String? relativeName) async {
  if (relativeName == null || relativeName.isEmpty) return null;
  final file = File('${(await _dir()).path}/$relativeName');
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

Future<void> deleteThumb(String? relativeName) async {
  if (relativeName == null || relativeName.isEmpty) return;
  final file = File('${(await _dir()).path}/$relativeName');
  if (await file.exists()) await file.delete();
}

Future<void> clearThumbs() async {
  final dir = await _dir();
  if (await dir.exists()) await dir.delete(recursive: true);
}
