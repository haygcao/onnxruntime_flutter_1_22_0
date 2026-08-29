import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:onnxruntime_v2/src/bindings/bindings.dart';
import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart'
    as bg;
import 'package:onnxruntime_v2/src/ort_provider.dart';
import 'package:onnxruntime_v2/src/ort_status.dart';

/// A class about onnx runtime environment.
class OrtEnv {
  static final OrtEnv _instance = OrtEnv._();

  static OrtEnv get instance => _instance;

  ffi.Pointer<bg.OrtEnv>? _ptr;

  late ffi.Pointer<bg.OrtApi> _ortApiPtr;

  static OrtApiVersion _apiVersion = OrtApiVersion.api20;

  OrtEnv._() {
    final getApiFn = onnxRuntimeBinding.OrtGetApiBase()
        .ref
        .GetApi
        .asFunction<ffi.Pointer<bg.OrtApi> Function(int)>();

    ffi.Pointer<bg.OrtApi> apiPtr = getApiFn(_apiVersion.value);
    if (apiPtr.address == 0) {
      // 若指定的版本超出当前动态库支持范围，自动自适应降级至当前动态库支持的最大可用版本
      for (int v = _apiVersion.value - 1; v >= 1; v--) {
        apiPtr = getApiFn(v);
        if (apiPtr.address != 0) {
          break;
        }
      }
    }
    if (apiPtr.address == 0) {
      throw StateError('Failed to initialize OrtApi: No supported API version found in the loaded ONNX Runtime library.');
    }
    _ortApiPtr = apiPtr;
  }

  /// Set ort's api version.
  static void setApiVersion(OrtApiVersion apiVersion) {
    _apiVersion = apiVersion;
  }

  /// Initialize the onnx runtime environment.
  void init(
      {OrtLoggingLevel level = OrtLoggingLevel.warning,
      String logId = 'DartOnnxRuntime',
      OrtThreadingOptions? options}) {
    final pp = calloc<ffi.Pointer<bg.OrtEnv>>();
    bg.OrtStatusPtr statusPtr;
    if (options == null) {
      statusPtr = _ortApiPtr.ref.CreateEnv.asFunction<
              bg.OrtStatusPtr Function(int, ffi.Pointer<ffi.Char>,
                  ffi.Pointer<ffi.Pointer<bg.OrtEnv>>)>()(
          level.value, logId.toNativeUtf8().cast<ffi.Char>(), pp);
    } else {
      statusPtr = _ortApiPtr.ref.CreateEnvWithGlobalThreadPools.asFunction<
              bg.OrtStatusPtr Function(
                  int,
                  ffi.Pointer<ffi.Char>,
                  ffi.Pointer<bg.OrtThreadingOptions>,
                  ffi.Pointer<ffi.Pointer<bg.OrtEnv>>)>()(
          level.value, logId.toNativeUtf8().cast<ffi.Char>(), options._ptr, pp);
    }
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    _setLanguageProjection();
    calloc.free(pp);
  }

  /// Release the onnx runtime environment.
  void release() {
    if (_ptr == null) {
      return;
    }
    _ortApiPtr.ref.ReleaseEnv
        .asFunction<void Function(ffi.Pointer<bg.OrtEnv>)>()(_ptr!);
    _ptr = null;
  }

  /// Gets the version of onnx runtime.
  static String get version => onnxRuntimeBinding.OrtGetApiBase()
      .ref
      .GetVersionString
      .asFunction<ffi.Pointer<ffi.Char> Function()>()()
      .cast<Utf8>()
      .toDartString();

  ffi.Pointer<bg.OrtApi> get ortApiPtr => _ortApiPtr;

  ffi.Pointer<bg.OrtEnv> get ptr {
    if (_ptr == null) {
      init();
    }
    return _ptr!;
  }

  /// Gets all available providers.
  List<OrtProvider> availableProviders() {
    final providersPtr = calloc<ffi.Pointer<ffi.Pointer<ffi.Char>>>();
    final lengthPtr = calloc<ffi.Int>();
    var statusPtr = ortApiPtr.ref.GetAvailableProviders.asFunction<
        bg.OrtStatusPtr Function(
            ffi.Pointer<ffi.Pointer<ffi.Pointer<ffi.Char>>>,
            ffi.Pointer<ffi.Int>)>()(providersPtr, lengthPtr);
    OrtStatus.checkOrtStatus(statusPtr);
    int length = lengthPtr.value;
    final list = List<OrtProvider>.generate(length, (index) {
      final provider = providersPtr.value[index].cast<Utf8>().toDartString();
      return OrtProvider.valueOf(provider);
    });
    statusPtr = ortApiPtr.ref.ReleaseAvailableProviders.asFunction<
        bg.OrtStatusPtr Function(ffi.Pointer<ffi.Pointer<ffi.Char>>,
            int)>()(providersPtr.value, lengthPtr.value);
    OrtStatus.checkOrtStatus(statusPtr);
    calloc.free(providersPtr);
    calloc.free(lengthPtr);
    return list;
  }

  void _setLanguageProjection() {
    if (_ptr == null) {
      init();
    }
    final status = _ortApiPtr.ref.SetLanguageProjection.asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtEnv>, int)>()(
        _ptr!, bg.OrtLanguageProjection.ORT_PROJECTION_C);
    OrtStatus.checkOrtStatus(status);
  }
}

/// An enumerated value of api's version.
enum OrtApiVersion {
  /// The initial release of the ORT API.
  api1(1),

  /// Post 1.0 builds of the ORT API.
  api2(2),

  /// Post 1.3 builds of the ORT API.
  api3(3),

  /// Post 1.6 builds of the ORT API.
  api7(7),

  /// Post 1.7 builds of the ORT API.
  api8(8),

  /// Post 1.10 builds of the ORT API.
  api11(11),

  /// Post 1.12 builds of the ORT API.
  api13(13),

  /// Post 1.13 builds of the ORT API.
  api14(14),

  /// Post 1.14 builds of the ORT API.
  api15(15),

  /// Post 1.15 builds of the ORT API.
  api16(16),

  /// Post 1.16 builds of the ORT API (supports IR 10).
  api17(17),

  /// Post 1.17 builds of the ORT API.
  api18(18),

  /// Post 1.18 builds of the ORT API.
  api19(19),

  /// Post 1.19 / 1.20+ builds of the ORT API.
  api20(20),

  /// Post 1.21+ builds of the ORT API.
  api21(21),

  /// Post 1.22+ builds of the ORT API.
  api22(22),

  /// Post 1.23+ builds of the ORT API.
  api23(23),

  /// Post 1.24+ builds of the ORT API.
  api24(24),

  /// Post 1.25+ builds of the ORT API.
  api25(25),

  /// The initial release of the ORT training API.
  trainingApi1(1);

  final int value;

  const OrtApiVersion(this.value);
}

/// An enumerated value of log's level.
enum OrtLoggingLevel {
  verbose(bg.OrtLoggingLevel.ORT_LOGGING_LEVEL_VERBOSE),
  info(bg.OrtLoggingLevel.ORT_LOGGING_LEVEL_INFO),
  warning(bg.OrtLoggingLevel.ORT_LOGGING_LEVEL_WARNING),
  error(bg.OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR),
  fatal(bg.OrtLoggingLevel.ORT_LOGGING_LEVEL_FATAL);

  final int value;

  const OrtLoggingLevel(this.value);
}

/// A class obout thread's options.
class OrtThreadingOptions {
  late ffi.Pointer<bg.OrtThreadingOptions> _ptr;

  OrtThreadingOptions() {
    _create();
  }

  void _create() {
    final pp = calloc<ffi.Pointer<bg.OrtThreadingOptions>>();
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.CreateThreadingOptions
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<ffi.Pointer<bg.OrtThreadingOptions>>)>()(pp);
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    calloc.free(pp);
  }

  void release() {
    OrtEnv.instance.ortApiPtr.ref.ReleaseThreadingOptions
        .asFunction<void Function(ffi.Pointer<bg.OrtThreadingOptions>)>()(_ptr);
  }

  /// Sets the number of global intra op threads.
  void setGlobalIntraOpNumThreads(int numThreads) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalIntraOpNumThreads
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtThreadingOptions>, int)>()(_ptr, numThreads);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  /// Sets the number of global inter op threads.
  void setGlobalInterOpNumThreads(int numThreads) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalInterOpNumThreads
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtThreadingOptions>, int)>()(_ptr, numThreads);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  /// Sets the global spin control.
  void setGlobalSpinControl(bool allowSpinning) {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalSpinControl
        .asFunction<
            bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtThreadingOptions>,
                int)>()(_ptr, allowSpinning ? 1 : 0);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  void setGlobalDenormalAsZero() {
    final statusPtr = OrtEnv.instance.ortApiPtr.ref.SetGlobalDenormalAsZero
        .asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<bg.OrtThreadingOptions>)>()(_ptr);
    OrtStatus.checkOrtStatus(statusPtr);
  }

  /// Sets the global intra op thread affinity.
  void setGlobalIntraOpThreadAffinity(String affinity) {
    final statusPtr =
        OrtEnv.instance.ortApiPtr.ref.SetGlobalIntraOpThreadAffinity.asFunction<
                bg.OrtStatusPtr Function(ffi.Pointer<bg.OrtThreadingOptions>,
                    ffi.Pointer<ffi.Char>)>()(
            _ptr, affinity.toNativeUtf8().cast<ffi.Char>());
    OrtStatus.checkOrtStatus(statusPtr);
  }
}

class OrtAllocator {
  late ffi.Pointer<bg.OrtAllocator> _ptr;

  static final OrtAllocator _instance = OrtAllocator._();

  static OrtAllocator get instance => _instance;

  ffi.Pointer<bg.OrtAllocator> get ptr => _ptr;

  OrtAllocator._() {
    final pp = calloc<ffi.Pointer<bg.OrtAllocator>>();
    final statusPtr =
        OrtEnv.instance.ortApiPtr.ref.GetAllocatorWithDefaultOptions.asFunction<
            bg.OrtStatusPtr Function(
                ffi.Pointer<ffi.Pointer<bg.OrtAllocator>>)>()(pp);
    OrtStatus.checkOrtStatus(statusPtr);
    _ptr = pp.value;
    calloc.free(pp);
  }
}
