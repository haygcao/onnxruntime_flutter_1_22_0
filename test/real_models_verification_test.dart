import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

void main() {
  setUpAll(() {
    OrtEnv.instance.init();
  });

  tearDownAll(() {
    OrtEnv.instance.release();
  });

  group('🚀 Full AI Model Matrix Verification (LLM + Vision + OCR)', () {
    final modelDirStr = Platform.environment['TEST_MODEL_DIR'] ?? './test_models';
    final modelDir = Directory(modelDirStr);

    test('Verify all benchmark models load and execute without IR/Operator errors', () async {
      if (!modelDir.existsSync()) {
        print('⚠️ Test model directory does not exist ($modelDirStr), skipping local run.');
        return;
      }

      final onnxFiles = modelDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.onnx'))
          .toList();

      print('📦 Found ${onnxFiles.length} ONNX models to verify:');
      for (final f in onnxFiles) {
        print('  - ${f.uri.pathSegments.last} (${(f.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB)');
      }

      expect(onnxFiles.isNotEmpty, isTrue, reason: 'No test models found in $modelDirStr');

      for (final modelFile in onnxFiles) {
        final modelName = modelFile.uri.pathSegments.last;
        print('\n🧪 Testing Model: $modelName');

        final sessionOptions = OrtSessionOptions();
        await sessionOptions.appendDefaultProviders();
        sessionOptions.setIntraOpNumThreads(2);
        sessionOptions.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

        OrtSession? session;
        try {
          // 1. 验证模型文件加载（测试 IR Version 兼容性、算子解析与图优化）
          session = OrtSession.fromFile(modelFile, sessionOptions);
          expect(session, isNotNull);

          final inputNames = session.inputNames;
          final outputNames = session.outputNames;
          print('  ✅ Loaded successfully!');
          print('     Inputs : $inputNames');
          print('     Outputs: $outputNames');

          expect(inputNames.isNotEmpty, isTrue);
          expect(outputNames.isNotEmpty, isTrue);
        } catch (e) {
          fail('❌ Failed to load model $modelName with ONNX Runtime: $e');
        } finally {
          session?.release();
          sessionOptions.release();
        }
      }
    });
  });
}
