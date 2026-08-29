# ONNX Runtime v1.28.1 Auto-Sync & Verification Report

- **Release Tag**: `v1.28.1`
- **Platforms Updated**: Windows (x64), Linux (x64)

### Verified CI Models (4 Models Sequentially Tested):
- **`ppocrv5_det_p9.onnx`** (`paddleocr_v5_det`) - *PP-OCRv5 Text Detection (4.8MB)* (`ocr_paddle`)
- **`ppocrv5_rec_p9.onnx`** (`paddleocr_v5_rec`) - *PP-OCRv5 Text Recognition (16.5MB)* (`ocr_paddle`)
- **`mangalens.onnx`** (`mangalens`) - *MangaLens Layout Segmentation (15MB)* (`detect_engine`)
- **`encoder_model.onnx`** (`manga_ocr_encoder`) - *Manga-OCR ViT Visual Encoder (20MB)* (`ocr_manga`)

**ABI Signature 100% Identical** (Seamless Drop-in Replacement).
