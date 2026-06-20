// file_platform_stub.dart
import 'dart:typed_data';

class File {
  File(String path);
  String get path => ''; // Implementação dummy
  Future<int> length() async => 0; // Implementação dummy
  Future<Uint8List> readAsBytes() async => Uint8List(0); // Implementação dummy
}