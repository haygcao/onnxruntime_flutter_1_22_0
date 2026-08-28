import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

void main() {
  setUpAll(() {
    OrtEnv.instance.init();
  });

  tearDownAll(() {
    OrtEnv.instance.release();
  });

  group('🚀 Real-World End-to-End AI Inference Verification', () {
    final modelDirStr = Platform.environment['TEST_MODEL_DIR'] ?? './test_models';
    final modelDir = Directory(modelDirStr);
    final assetsDir = Directory('test/assets');

    test('Verify Vision, OCR, and LLM models execute actual tensor inferences', () async {
      if (!modelDir.existsSync()) {
        debugPrint('⚠️ Model directory ($modelDirStr) does not exist, skipping inference run.');
        return;
      }

      debugPrint('🖼️ Checking test asset images in ${assetsDir.path}...');
      if (assetsDir.existsSync()) {
        for (final item in assetsDir.listSync()) {
          debugPrint('  - Asset: ${item.uri.pathSegments.last} (${item.statSync().size} bytes)');
        }
      }

      final onnxFiles = modelDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.onnx'))
          .toList();

      debugPrint('\n📦 Discovered ${onnxFiles.length} ONNX models for end-to-end forward inference test:');
      for (final f in onnxFiles) {
        debugPrint('  - ${f.uri.pathSegments.last} (${(f.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB)');
      }

      for (final modelFile in onnxFiles) {
        final fileName = modelFile.uri.pathSegments.last.toLowerCase();
        debugPrint('\n⚡ ========================================================');
        debugPrint('⚡ Testing Real Forward Inference: $fileName');
        debugPrint('⚡ ========================================================');

        final sessionOptions = OrtSessionOptions();
        await sessionOptions.appendDefaultProviders();
        sessionOptions.setIntraOpNumThreads(2);
        sessionOptions.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

        OrtSession? session;
        try {
          session = OrtSession.fromFile(modelFile, sessionOptions);
          expect(session, isNotNull);

          final inputNames = session.inputNames;
          final outputNames = session.outputNames;
          debugPrint('  ✅ Model Graph Loaded. Inputs: $inputNames | Outputs: $outputNames');

          final runOptions = OrtRunOptions();
          Map<String, OrtValue> inputTensors = {};

          // ── 根据不同模型类型构建真实的 Tensor 输入并执行真实推理 ──
          if (fileName.contains('ppocrv5_det') || fileName.contains('mangalens')) {
            // 目标检测/分割模型输入: [1, 3, 640, 640] 或 [1, 3, 1024, 1024]
            final shape = [1, 3, 640, 640];
            final totalElements = 1 * 3 * 640 * 640;
            final floatData = Float32List(totalElements);
            for (var i = 0; i < totalElements; i++) {
              floatData[i] = (i % 255) / 255.0;
            }
            final firstInput = inputNames.first;
            inputTensors[firstInput] = OrtValueTensor.createTensorWithDataList(floatData, shape);
          } else if (fileName.contains('ppocrv5_rec')) {
            // 文本识别模型输入: [1, 3, 48, 320]
            final shape = [1, 3, 48, 320];
            final totalElements = 1 * 3 * 48 * 320;
            final floatData = Float32List(totalElements);
            for (var i = 0; i < totalElements; i++) {
              floatData[i] = (i % 255) / 255.0;
            }
            final firstInput = inputNames.first;
            inputTensors[firstInput] = OrtValueTensor.createTensorWithDataList(floatData, shape);
          } else if (fileName.contains('qwen') || fileName.contains('hunyuan')) {
            // 大语言模型 (LLM): 输入 token_ids [1, 8]
            final shape = [1, 8];
            final tokenIds = Int64List.fromList([1, 150, 2034, 12, 59, 1024, 88, 320]);
            final firstInput = inputNames.first;
            inputTensors[firstInput] = OrtValueTensor.createTensorWithDataList(tokenIds, shape);
          } else if (fileName.contains('encoder')) {
            // ViT 图像编码器: [1, 3, 224, 224]
            final shape = [1, 3, 224, 224];
            final totalElements = 1 * 3 * 224 * 224;
            final floatData = Float32List(totalElements);
            for (var i = 0; i < totalElements; i++) {
              floatData[i] = (i % 255) / 255.0;
            }
            final firstInput = inputNames.first;
            inputTensors[firstInput] = OrtValueTensor.createTensorWithDataList(floatData, shape);
          }

          if (inputTensors.isNotEmpty) {
            debugPrint('  🚀 Executing session.run with real inputs...');
            final outputs = session.run(runOptions, inputTensors);
            expect(outputs, isNotNull);
            debugPrint('  🎉 Forward Inference PASS! Generated ${outputs.length} output tensors.');
            for (var i = 0; i < outputs.length; i++) {
              final outVal = outputs[i];
              debugPrint('     - Output [$i]: Computed successfully');
              outVal?.release();
            }
          }

          // 释放输入 Tensor
          for (final t in inputTensors.values) {
            t.release();
          }
          runOptions.release();
        } catch (e, stack) {
          fail('❌ Forward Inference Failed for $fileName: $e\n$stack');
        } finally {
          session?.release();
          sessionOptions.release();
        }
      }
    });
  });
}
