import 'dart:ffi';
import 'dart:io';
import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart';

final DynamicLibrary _dylib = () {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libonnxruntime.so');
  }

  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }

  if (Platform.isMacOS) {
    try {
      final macFile = File('macos/libonnxruntime.dylib');
      if (macFile.existsSync()) {
        return DynamicLibrary.open(macFile.absolute.path);
      }
      final localFile = File('libonnxruntime.dylib');
      if (localFile.existsSync()) {
        return DynamicLibrary.open(localFile.absolute.path);
      }
    } catch (_) {}
    return DynamicLibrary.open('libonnxruntime.dylib');
  }

  if (Platform.isWindows) {
    try {
      final winFile = File('windows/onnxruntime.dll');
      if (winFile.existsSync()) {
        return DynamicLibrary.open(winFile.absolute.path);
      }
      final localFile = File('onnxruntime.dll');
      if (localFile.existsSync()) {
        return DynamicLibrary.open(localFile.absolute.path);
      }
    } catch (_) {}
    return DynamicLibrary.open('onnxruntime.dll');
  }

  if (Platform.isLinux) {
    try {
      final linuxFile = File('linux/libonnxruntime.so');
      if (linuxFile.existsSync()) {
        return DynamicLibrary.open(linuxFile.absolute.path);
      }
      final localFile = File('libonnxruntime.so');
      if (localFile.existsSync()) {
        return DynamicLibrary.open(localFile.absolute.path);
      }
    } catch (_) {}
    return DynamicLibrary.open('libonnxruntime.so');
  }

  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// OnnxRuntime Bindings
final onnxRuntimeBinding = OnnxRuntimeBindings(_dylib);
