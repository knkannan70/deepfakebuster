import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';

// Moved to top level
class PreprocessingValidation {
  final bool isValid;
  final String message;
  final double averageBrightness; // Normalized brightness [0, 1]

  PreprocessingValidation({
    required this.isValid,
    required this.message,
    required this.averageBrightness,
  });
}

class ModelService {
  static const String _model1Path =
      'assets/models/face_swap_detector_compatible.tflite';
  static const String _model2Path =
      'assets/models/deepfake_mobilenet_compatible.tflite';

  late Interpreter _model1;
  late Interpreter _model2;
  bool _isInitialized = false;

  Function(double)? _progressCallback;
  bool _isCancelled = false;
  Map<String, dynamic>? _lastAnalysisResult;
  final List<String> _analysisHistory = [];
  int _framesUsedModel1 = 0;
  int _framesUsedModel2 = 0;

  bool get areModelsInitialized => _isInitialized;
  Map<String, dynamic>? get lastAnalysisResult => _lastAnalysisResult;
  List<String> get analysisHistory => _analysisHistory;
  int get framesUsedModel1 => _framesUsedModel1;
  int get framesUsedModel2 => _framesUsedModel2;

  Map<String, String>? getFormattedResults() {
    if (_lastAnalysisResult == null) return null;
    return {
      'status': _lastAnalysisResult?['final_label'] ?? 'INCONCLUSIVE',
      'confidence': ((_lastAnalysisResult?['combined_confidence'] ?? 0.0) * 100)
          .toStringAsFixed(1),
    };
  }

  void setProgressCallback(Function(double)? callback) {
    _progressCallback = callback;
  }

  void cancelAnalysis() {
    _isCancelled = true;
  }

  Future<void> initializeModels() async {
    if (_isInitialized) return;
    try {
      // Use options to potentially improve compatibility or performance
      final options = InterpreterOptions();
      // options.addDelegate(XNNPackDelegate()); // Optional: Can sometimes help

      _model1 = await Interpreter.fromAsset(_model1Path, options: options);
      _model2 = await Interpreter.fromAsset(_model2Path, options: options);
      _inspectModelShapes();
      print('Models loaded successfully');
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize models: $e');
    }
  }

  void _inspectModelShapes() {
    // Allocate tensors initially
    try {
      _model1.allocateTensors();
      _model2.allocateTensors();
    } catch (e) {
      print("Warning: Could not allocate tensors on init: $e");
    }

    print('=== Model 1 Inspection ===');
    print('Input tensors (initial): ${_model1.getInputTensors()}');
    print('Output tensors (initial): ${_model1.getOutputTensors()}');
    print('=== Model 2 Inspection ===');
    print('Input tensors (initial): ${_model2.getInputTensors()}');
    print('Output tensors (initial): ${_model2.getOutputTensors()}');
  }

  Future<Map<String, dynamic>> analyzeVideo(String videoPath) async {
    // ... (rest of the function remains the same as previous version) ...
    if (!_isInitialized) {
      await initializeModels();
    }
    _isCancelled = false;
    _progressCallback?.call(0.0);
    final videoFile = File(videoPath);

    try {
      final videoInfo = await _getVideoInfo(videoFile);
      if (videoInfo == null) {
        throw Exception('Failed to retrieve video information.');
      }
      if (_isCancelled) throw Exception('Analysis cancelled');

      final duration = Duration(seconds: videoInfo['duration_seconds'] ?? 0);
      final positiveDuration =
          duration > Duration.zero ? duration : const Duration(seconds: 1);
      final frames = await _extractFrames(videoFile, positiveDuration);
      if (_isCancelled) throw Exception('Analysis cancelled');
      if (frames.isEmpty) throw Exception('No frames extracted from video.');

      final analysisResults = await _analyzeFrames(frames);
      if (_isCancelled) throw Exception('Analysis cancelled');

      final finalResult = _calculateFinalResult(analysisResults);

      final Map<String, dynamic> rawResult = {
        'video_info': videoInfo,
        'total_frames': analysisResults['total_frames_extracted'],
        'fake_frames_model1': analysisResults['fake_frames_model1'],
        'fake_frames_model2': analysisResults['fake_frames_model2'],
        'valid_frames_model1': analysisResults['valid_frames_model1'],
        'valid_frames_model2': analysisResults['valid_frames_model2'],
        'model1_confidence': analysisResults['model1_confidence'],
        'model2_confidence': analysisResults['model2_confidence'],
        'final_label': finalResult['final_label'],
        'combined_confidence': finalResult['combined_confidence'],
      };

      _lastAnalysisResult = rawResult;
      _analysisHistory.add("Analyzed: ${videoInfo['file_name']}");
      _framesUsedModel1 = analysisResults['valid_frames_model1'] ?? 0;
      _framesUsedModel2 = analysisResults['valid_frames_model2'] ?? 0;
      _progressCallback?.call(1.0);

      return rawResult;
    } catch (e) {
      _isCancelled = false;
      _progressCallback?.call(0.0);
      print("Error during video analysis: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getVideoInfo(File videoFile) async {
    // ... (remains the same as previous version) ...
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      Duration duration = controller.value.duration;
      int retries = 0;
      while (duration <= Duration.zero && retries < 5) {
        await Future.delayed(const Duration(milliseconds: 100));
        duration = controller.value.duration;
        retries++;
      }
      await controller.dispose();

      if (duration <= Duration.zero) {
        print(
          "Warning: Video duration reported as zero or negative after retries.",
        );
      }

      final stat = await videoFile.stat();
      final fileSizeMB = stat.size / (1024 * 1024);

      return {
        'file_name': videoFile.path.split('/').last,
        'file_size_mb': fileSizeMB.toStringAsFixed(2),
        'duration_seconds': duration.inSeconds,
        'path': videoFile.path,
      };
    } catch (e) {
      await controller?.dispose();
      print('Failed to get video info from ModelService: $e');
      return null;
    }
  }

  Map<String, dynamic> _calculateFinalResult(
    Map<String, dynamic> analysisData,
  ) {
    // ... (remains the same as previous version) ...
    double m1Score = analysisData['model1_confidence'] ?? 0.0;
    double m2Score = analysisData['model2_confidence'] ?? 0.0;
    double combinedConfidence = (m1Score + m2Score) / 2.0;

    String finalLabel;
    if (combinedConfidence > 0.75) {
      finalLabel = 'LIKELY DEEPFAKE';
    } else if (combinedConfidence > 0.40) {
      finalLabel = 'POSSIBLY MANIPULATED';
    } else {
      finalLabel = 'LIKELY AUTHENTIC';
    }

    return {
      'final_label': finalLabel,
      'combined_confidence': combinedConfidence,
    };
  }

  Future<List<Uint8List>> _extractFrames(
    File videoFile,
    Duration duration,
  ) async {
    // ... (remains the same as previous version) ...
    final List<Uint8List> frames = [];
    const int totalFrames = 24;
    final int durationMs = duration.inMilliseconds;

    if (durationMs <= 0) {
      print("Error: Cannot extract frames from video with zero duration.");
      return frames;
    }

    for (int i = 0; i < totalFrames; i++) {
      if (_isCancelled) {
        throw Exception('Analysis cancelled during frame extraction');
      }
      final timeInMs = (durationMs * i / totalFrames).round();
      try {
        final frame = await VideoThumbnail.thumbnailData(
          video: videoFile.path,
          imageFormat: ImageFormat.JPEG,
          quality: 85,
          timeMs: timeInMs,
          maxWidth: 500,
        );
        if (frame != null && frame.lengthInBytes > 1000) {
          frames.add(frame);
        } else {
          print('⚠️ Frame $i extraction failed or too small at ${timeInMs}ms');
        }
      } catch (e) {
        print('Error extracting frame at $timeInMs ms: $e');
      }
      _progressCallback?.call((i + 1) / (totalFrames * 2));
    }
    print('Extracted ${frames.length} frames (expected up to: $totalFrames)');
    return frames;
  }

  Future<Map<String, dynamic>> _analyzeFrames(List<Uint8List> frames) async {
    // ... (rest of the function remains the same as previous version) ...
    int fakeFramesModel1 = 0, validFramesModel1 = 0;
    double totalProbModel1 = 0.0;
    int fakeFramesModel2 = 0, validFramesModel2 = 0;
    double totalProbModel2 = 0.0;
    int totalValidFramesProcessed = 0;

    for (int i = 0; i < frames.length; i++) {
      if (_isCancelled) {
        throw Exception('Analysis cancelled during frame analysis');
      }
      final frame = frames[i];
      try {
        // Preprocess frame -> returns FLAT Float32List [0.0, 1.0]
        final Float32List inputList = await _preprocessFrame(frame);

        final validation = _validatePreprocessing(inputList);
        if (!validation.isValid) {
          print('🚫 Skipping frame $i: ${validation.message}');
          continue;
        }

        totalValidFramesProcessed++;

        // --- Run Model 1 ---
        final result1 = await _runModel(_model1, inputList);
        totalProbModel1 += result1;
        validFramesModel1++;
        if (result1 > 0.5) fakeFramesModel1++;

        // --- Run Model 2 ---
        final result2 = await _runModel(_model2, inputList);
        totalProbModel2 += result2;
        validFramesModel2++;
        if (result2 > 0.5) fakeFramesModel2++;

        _progressCallback?.call(0.5 + ((i + 1) / (frames.length * 2)));

        print(
          'Frame $i: M1=${(result1 * 100).toStringAsFixed(1)}% | M2=${(result2 * 100).toStringAsFixed(1)}% (Brightness: ${validation.averageBrightness.toStringAsFixed(3)})',
        );

        await Future.delayed(Duration.zero);
      } catch (e) {
        print('Error analyzing frame $i: $e');
      }
    }

    final double avgProbModel1 =
        validFramesModel1 > 0 ? totalProbModel1 / validFramesModel1 : 0.0;
    final double avgProbModel2 =
        validFramesModel2 > 0 ? totalProbModel2 / validFramesModel2 : 0.0;

    print('📊 Analysis Summary:');
    print(
      '   Valid frames processed: $totalValidFramesProcessed/${frames.length}',
    );
    print(
      '   Model 1: $fakeFramesModel1 fake frames ($validFramesModel1 valid) (Avg Prob: ${(avgProbModel1 * 100).toStringAsFixed(2)}%)',
    );
    print(
      '   Model 2: $fakeFramesModel2 fake frames ($validFramesModel2 valid) (Avg Prob: ${(avgProbModel2 * 100).toStringAsFixed(2)}%)',
    );

    return {
      'model1_confidence': avgProbModel1,
      'model2_confidence': avgProbModel2,
      'fake_frames_model1': fakeFramesModel1,
      'fake_frames_model2': fakeFramesModel2,
      'valid_frames_model1': validFramesModel1,
      'valid_frames_model2': validFramesModel2,
      'total_frames_extracted': frames.length,
    };
  }

  bool _isImageCorrupted(img.Image image) {
    // ... (remains the same as previous version) ...
    int darkPixels = 0;
    int totalPixels = image.width * image.height;
    if (totalPixels == 0) return true;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final int pixel = image.getPixel(x, y);
        if (img.getRed(pixel) < 10 &&
            img.getGreen(pixel) < 10 &&
            img.getBlue(pixel) < 10) {
          darkPixels++;
        }
      }
    }
    return (darkPixels / totalPixels) > 0.8;
  }

  PreprocessingValidation _validatePreprocessing(Float32List inputList) {
    // ... (remains the same as previous version) ...
    if (inputList.isEmpty) {
      return PreprocessingValidation(
        isValid: false,
        message: 'Validation error: Input list is empty.',
        averageBrightness: 0.0,
      );
    }
    const expectedSize = 1 * 224 * 224 * 3;
    if (inputList.length != expectedSize) {
      return PreprocessingValidation(
        isValid: false,
        message:
            'Validation error: Input list size mismatch. Expected $expectedSize, got ${inputList.length}',
        averageBrightness: 0.0,
      );
    }

    double sum = 0.0;
    for (int i = 0; i < inputList.length; i++) {
      sum += inputList[i];
    }
    double average = sum / inputList.length;

    if (average < 0.05) {
      return PreprocessingValidation(
        isValid: false,
        message: 'Image too dark (avg: ${average.toStringAsFixed(4)})',
        averageBrightness: average,
      );
    }
    if (average > 0.95) {
      return PreprocessingValidation(
        isValid: false,
        message: 'Image too bright (avg: ${average.toStringAsFixed(4)})',
        averageBrightness: average,
      );
    }

    return PreprocessingValidation(
      isValid: true,
      message: 'OK',
      averageBrightness: average,
    );
  }

  Future<Float32List> _preprocessFrame(Uint8List frameData) async {
    // ... (remains the same as previous version - THIS IS CORRECT) ...
    try {
      final image = img.decodeImage(frameData);
      if (image == null) {
        throw Exception('Failed to decode image from frame data');
      }
      if (_isImageCorrupted(image)) {
        throw Exception('Image appears corrupted/dark');
      }

      img.Image rgbImage = image;
      if (image.numberOfChannels != 3) {
        rgbImage = _convertToRGB(image);
      }

      final resized = img.copyResize(rgbImage, width: 224, height: 224);

      // Creates a flat list of 1 * 224 * 224 * 3 = 150528 float values
      final Float32List inputList = Float32List(1 * 224 * 224 * 3);
      int index = 0;
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final int pixel = resized.getPixel(x, y);
          // Normalize [0, 255] to [0.0, 1.0] to match Python script
          inputList[index++] = img.getRed(pixel) / 255.0;
          inputList[index++] = img.getGreen(pixel) / 255.0;
          inputList[index++] = img.getBlue(pixel) / 255.0;
        }
      }
      return inputList; // Return the flat list
    } catch (e) {
      print('❌ Preprocessing error: $e');
      rethrow;
    }
  }

  img.Image _convertToRGB(img.Image image) {
    // ... (remains the same as previous version) ...
    final rgbImage = img.Image(image.width, image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final int pixel = image.getPixel(x, y);
        rgbImage.setPixelRgba(
          x,
          y,
          img.getRed(pixel),
          img.getGreen(pixel),
          img.getBlue(pixel),
          255,
        );
      }
    }
    return rgbImage;
  }

  // --- **MODIFIED _runModel USING ByteBuffer AND runForMultipleInputs** ---
  Future<double> _runModel(Interpreter model, Float32List inputList) async {
    try {
      // 1. Force-resize the input tensor shape JUST before running.
      //    This tells the interpreter the shape of the flat buffer.
      model.resizeInputTensor(0, [1, 224, 224, 3]);

      // 2. Re-allocate tensors AFTER resizing. Crucial step!
      model.allocateTensors();

      // 3. Prepare the INPUTS list using the ByteBuffer of the Float32List.
      //    runForMultipleInputs expects List<Object>.
      final inputs = <Object>[inputList.buffer];

      // 4. Prepare the OUTPUTS map.
      //    The key is the output tensor index (0).
      //    The value is the buffer where the output will be written.
      //    We create a Float32List for the output shape [1, 1] and use its buffer.
      final outputBuffer = Float32List(1); // Shape [1, 1] has 1 element
      final outputs = <int, Object>{0: outputBuffer.buffer};

      // 5. Run inference using runForMultipleInputs.
      model.runForMultipleInputs(inputs, outputs);

      // 6. Extract the result from the outputBuffer Float32List.
      //    The result for shape [1, 1] is at index 0.
      double fakeProbability = outputBuffer[0];

      return fakeProbability.clamp(0.0, 1.0);
    } catch (e) {
      print('Model inference error for model ${model.hashCode}: $e');
      // If it STILL fails with the ByteBuffer approach, log details.
      print('InputList length: ${inputList.length}');
      print('InputList buffer byteLength: ${inputList.buffer.lengthInBytes}');
      print('InputList type: ${inputList.runtimeType}');
      // Check tensor details AFTER resize attempt
      try {
        print(
          'Input tensor details AFTER resize attempt: ${model.getInputTensor(0)}',
        );
      } catch (e2) {
        print('Could not get input tensor details after resize: $e2');
      }
      return 0.5; // Return neutral probability on error
    }
  }
  // --- **END OF MODIFIED _runModel** ---

  void dispose() {
    // ... (remains the same as previous version) ...
    try {
      _model1.close();
      _model2.close();
    } catch (e) {
      print("Error closing TFLite interpreters: $e");
    }
    _isInitialized = false;
  }
}
