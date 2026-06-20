// image_service_web.dart
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'image_service_interface.dart';

class ImageService implements IImageService {
  @override
  Future<List<XFile>> compressImages(
    List<XFile> images, {
    int quality = 50,
    int minWidth = 1024,
  }) async {
    final List<XFile> result = [];

    for (final xfile in images) {
      try {
        final bytes = await xfile.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image == null) {
          result.add(xfile);
          continue;
        }

        final resized = img.copyResize(image, width: minWidth);
        final encoded = img.encodeJpg(resized, quality: quality);

        result.add(XFile.fromData(
          encoded,
          name: 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        ));
      } catch (e) {
        result.add(xfile); // fallback: original
      }
    }

    return result;
  }
}