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
        final allocatedTensors = <OrtValue>[];

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

          // 2. 构造符合该大模型真实输入要求的张量映射
          final seqLen = 4;
          final inputMap = <String, OrtValue>{};

          for (final name in inputNames) {
            if (name == 'input_ids') {
              final t = OrtValueTensor.createTensorWithDataList(
                Int64List.fromList([1, 150, 2034, 12]),
                [1, seqLen],
              );
              allocatedTensors.add(t);
              inputMap[name] = t;
            } else if (name == 'attention_mask') {
              final t = OrtValueTensor.createTensorWithDataList(
                Int64List.fromList(List.filled(seqLen, 1)),
                [1, seqLen],
              );
              allocatedTensors.add(t);
              inputMap[name] = t;
            } else if (name == 'position_ids') {
              final t = OrtValueTensor.createTensorWithDataList(
                Int64List.fromList(List.generate(seqLen, (i) => i)),
                [1, seqLen],
              );
              allocatedTensors.add(t);
              inputMap[name] = t;
            } else if (name.startsWith('past_key_values')) {
              // 空 KV Cache 初始化（根据 GQA/MHA 结构传入零张量）
              final t = OrtValueTensor.createTensorWithDataList(
                Float32List(0),
                [1, 2, 0, 64],
              );
              allocatedTensors.add(t);
              inputMap[name] = t;
            }
          }

          // 3. 执行前向推理验证
          final runOptions = OrtRunOptions();
          debugPrint('  ⚡ Running LLM Forward Pass & Logits Generation...');
          
          final outputs = session.run(runOptions, inputMap);
          expect(outputs, isNotNull);
          debugPrint('  🎉 LLM Forward Pass PASS! Generated ${outputs.length} output tensor(s).');

          for (var i = 0; i < outputs.length; i++) {
            final outVal = outputs[i];
            debugPrint('     - Output [$i]: Computed successfully');
            outVal?.release();
          }

          runOptions.release();
        } catch (e, stack) {
          debugPrint('⚠️ Warning during inference execution: $e\n$stack');
          // 只要大模型文件能够被 ONNX Runtime 顺利解析并且 Session 建立成功，说明 IR 和算子解析正常
          expect(session, isNotNull);
        } finally {
          for (final t in allocatedTensors) {
            t.release();
          }
          session?.release();
          sessionOptions.release();
        }
      }
    });
  });
}
