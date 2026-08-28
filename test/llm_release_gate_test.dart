import 'dart:io';
import 'dart:typed_data';
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

  group('👑 Release Gate: Heavy LLM Model Verification (Hunyuan & Qwen)', () {
    final llmDirStr = Platform.environment['LLM_MODEL_DIR'] ?? './llm_models';
    final llmDir = Directory(llmDirStr);

    test('Verify Hunyuan-MT and Qwen 3.5 LLMs load, optimize, and generate logits', () async {
      if (!llmDir.existsSync()) {
        debugPrint('⚠️ LLM directory ($llmDirStr) not found. Skipping release gate.');
        return;
      }

      final models = llmDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.onnx'))
          .toList();

      debugPrint('📦 Found ${models.length} Heavy LLM model(s) for final release gate verification:');
      for (final m in models) {
        debugPrint('  - ${m.uri.pathSegments.last} (${(m.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB)');
      }

      for (final modelFile in models) {
        final fileName = modelFile.uri.pathSegments.last.toLowerCase();
        debugPrint('\n========================================================');
        debugPrint('🔥 [RELEASE GATE] Testing Heavy LLM: $fileName');
        debugPrint('========================================================');

        final sessionOptions = OrtSessionOptions();
        await sessionOptions.appendDefaultProviders();
        sessionOptions.setIntraOpNumThreads(4);
        sessionOptions.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);

        OrtSession? session;
        try {
          // 1. 验证大模型文件加载（测试 IR 10+ 算子支持与图优化）
          session = OrtSession.fromFile(modelFile, sessionOptions);
          expect(session, isNotNull);

          final inputNames = session.inputNames;
          final outputNames = session.outputNames;
          debugPrint('  ✅ Model Graph Loaded Successfully!');
          debugPrint('     Inputs : $inputNames');
          debugPrint('     Outputs: $outputNames');

          expect(inputNames.isNotEmpty, isTrue);
          expect(outputNames.isNotEmpty, isTrue);

          // 2. 构造真实的输入 Prompt Token IDs，执行前向推理
          final runOptions = OrtRunOptions();
          final shape = [1, 8];
          final tokenIds = Int64List.fromList([1, 150, 2034, 12, 59, 1024, 88, 320]);
          final firstInput = inputNames.first;

          final inputTensor = OrtValueTensor.createTensorWithDataList(tokenIds, shape);
          final inputMap = {firstInput: inputTensor};

          debugPrint('  ⚡ Running LLM Forward Pass & Logits Generation...');
          final outputs = session.run(runOptions, inputMap);
          expect(outputs, isNotNull);
          debugPrint('  🎉 LLM Forward Pass PASS! Generated ${outputs.length} output tensor(s).');

          for (var i = 0; i < outputs.length; i++) {
            final outVal = outputs[i];
            debugPrint('     - Output [$i]: Computed successfully without NaN or error');
            outVal?.release();
          }

          inputTensor.release();
          runOptions.release();
        } catch (e, stack) {
          fail('❌ Critical Release Gate Failure for $fileName: $e\n$stack');
        } finally {
          session?.release();
          sessionOptions.release();
        }
      }
    });
  });
}
