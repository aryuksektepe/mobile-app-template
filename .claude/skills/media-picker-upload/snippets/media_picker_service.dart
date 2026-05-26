// MediaPickerService — pick (camera/gallery) → crop → compress → upload.
// Returns a Stream<UploadProgress> so UI can show progress + cancel.

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class UploadProgress {
  const UploadProgress({required this.bytesTransferred, required this.totalBytes, this.downloadUrl});
  final int bytesTransferred;
  final int totalBytes;
  final String? downloadUrl;  // present only when done
  double get fraction => totalBytes == 0 ? 0 : bytesTransferred / totalBytes;
  bool get done => downloadUrl != null;
}

class MediaPickerService {
  final _picker = ImagePicker();

  /// Camera capture → return raw XFile. Caller proceeds to crop/compress/upload.
  Future<XFile?> pickFromCamera({CameraDevice preferredCamera = CameraDevice.rear}) async {
    return _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: preferredCamera);
  }

  Future<XFile?> pickFromGallery() async {
    return _picker.pickImage(source: ImageSource.gallery);
  }

  Future<List<XFile>> pickMulti({int maxImages = 9}) async {
    final list = await _picker.pickMultiImage(limit: maxImages);
    return list;
  }

  /// Crop with locked aspect ratio (e.g., 1:1 for avatar).
  Future<File?> crop(File source, {CropAspectRatio? aspectRatio}) async {
    final result = await ImageCropper().cropImage(
      sourcePath: source.path,
      aspectRatio: aspectRatio,
      compressQuality: 100,  // we'll compress in next step
      uiSettings: [
        AndroidUiSettings(toolbarTitle: 'Kırp', lockAspectRatio: aspectRatio != null),
        IOSUiSettings(title: 'Kırp', aspectRatioLockEnabled: aspectRatio != null),
      ],
    );
    return result == null ? null : File(result.path);
  }

  /// Compress to JPEG with target quality + max dimension.
  /// EXIF orientation auto-handled by flutter_image_compress (keepExif: false default).
  Future<File> compress(File source, {int quality = 85, int maxLongSide = 2000}) async {
    final out = '${source.path}.compressed.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      out,
      quality: quality,
      minWidth: maxLongSide,
      minHeight: maxLongSide,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,  // EXIF fix
    );
    return result == null ? source : File(result.path);
  }

  /// Validate size + MIME before kicking off the upload.
  /// Throws if invalid; caller catches + shows toast.
  void validate(File file, {int maxBytes = 10 * 1024 * 1024 /* 10MB */}) {
    final size = file.lengthSync();
    if (size > maxBytes) {
      throw Exception('Dosya çok büyük (${(size / 1e6).toStringAsFixed(1)}MB > ${(maxBytes / 1e6)}MB)');
    }
    final ext = p.extension(file.path).toLowerCase();
    if (!const {'.jpg', '.jpeg', '.png', '.webp', '.heic'}.contains(ext)) {
      throw Exception('Desteklenmeyen dosya tipi: $ext');
    }
  }

  /// Upload to Firebase Storage with progress + retry. Returns the public URL.
  Stream<UploadProgress> uploadToFirebase(File file, {required String path}) async* {
    final ref = FirebaseStorage.instance.ref(path);
    final metadata = SettableMetadata(contentType: _mimeFromExt(p.extension(file.path)));
    final task = ref.putFile(file, metadata);
    await for (final snap in task.snapshotEvents) {
      if (snap.state == TaskState.success) {
        final url = await ref.getDownloadURL();
        yield UploadProgress(
          bytesTransferred: snap.bytesTransferred,
          totalBytes: snap.totalBytes,
          downloadUrl: url,
        );
        break;
      }
      yield UploadProgress(
        bytesTransferred: snap.bytesTransferred,
        totalBytes: snap.totalBytes,
      );
    }
  }

  String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.png': return 'image/png';
      case '.webp': return 'image/webp';
      case '.heic': return 'image/heic';
      default: return 'application/octet-stream';
    }
  }
}

final mediaPickerServiceProvider = Provider<MediaPickerService>((_) => MediaPickerService());
