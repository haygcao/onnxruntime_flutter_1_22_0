# ONNX Runtime v1.30.1 Auto-Sync & Verification Report

- **Release Tag**: `v1.30.1`
- **Platforms Updated**: Windows (x64), Linux (x64), macOS (onnxruntime-osx-arm64-1.30.1.tgz), Android (Maven AAR: 1.31.1), iOS (CocoaPods: 1.30.0, Deployment Target: 15.1)

### Verified CI Models (4 Models Sequentially Tested):
- **`ppocrv5_det_p9.onnx`** (`paddleocr_v5_det`) - *PP-OCRv5 Text Detection (4.8MB)* (`ocr_paddle`)
- **`ppocrv5_rec_p9.onnx`** (`paddleocr_v5_rec`) - *PP-OCRv5 Text Recognition (16.5MB)* (`ocr_paddle`)
- **`mangalens.onnx`** (`mangalens`) - *MangaLens Layout Segmentation (15MB)* (`detect_engine`)
- **`encoder_model.onnx`** (`manga_ocr_encoder`) - *Manga-OCR ViT Visual Encoder (20MB)* (`ocr_manga`)

### Deprecated / Removed APIs:
- `CreateModelPackageContext`
- `CreateModelPackageOptionsFromSessionOptions`
- `ModelCompilationOptions_SetEpContextDataWriteFunc`
- `ModelCompilationOptions_SetOutputModelExternalInitializersAlignment`
- `ModelCompilationOptions_SetOutputModelExternalInitializersBuffer`
- `ModelPackageComponent_GetSelectedVariantFolderPath`
- `ModelPackageComponent_GetSelectedVariantName`
- `ModelPackage_GetComponentCount`
- `ModelPackage_GetComponentNames`
- `ModelPackage_GetSchemaVersion`
- `ModelPackage_GetVariantCount`
- `ModelPackage_GetVariantEpName`
- `ModelPackage_GetVariantNames`
- `ModelPackage_ResolveStringRef`
- `SelectComponent`
- `SessionOptionsSetEpContextDataReadFunc`

