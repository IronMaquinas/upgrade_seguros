// image_service_mobile.dart
// ignore_for_file: unused_import

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'image_service_interface.dart';

class ImageService implements IImageService {
  @override
  Future<List<XFile>> compressImages(
    List<XFile> images, {
    int quality = 50,
    int minWidth = 1024, // ✅ Adicionado
  }) async {
    final List<XFile> result = [];

    for (final xfile in images) {
      try {
        final file = File(xfile.path);
        final bytes = file.readAsBytesSync();
        final image = img.decodeImage(bytes);

        if (image == null) continue;

        // Usa minWidth para redimensionar
        final resized = img.copyResize(image, width: minWidth);
        final encoded = img.encodeJpg(resized, quality: quality);

        final newXFile = XFile.fromData(
          encoded,
          name: 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        );

        result.add(newXFile);
      } catch (e) {
        result.add(xfile); // fallback
      }
    }

    return result;
  }
}