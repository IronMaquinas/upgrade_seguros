// image_service_interface.dart
import 'package:image_picker/image_picker.dart';

abstract class IImageService {
  Future<List<XFile>> compressImages(
    List<XFile> images, {
    int quality = 50,
    int minWidth = 1024,
  });
}