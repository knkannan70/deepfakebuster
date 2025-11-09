// analysis_result.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // Import for Color objects

class AnalysisResult {
  final String videoName;
  final String videoPath;
  final String duration;
  final int totalFrames; // Total frames extracted
  final int fakeFrames; // Final combined fake frames count
  final int originalFrames; // Final combined original frames count
  final double confidenceScore; // Combined confidence (0-100)
  final Map<String, double> modelScores;
  final List<Map<String, String>> fakeSegments;
  final DateTime timestamp;
  final String detailedReport;
  final Map<String, dynamic> model1Details;
  final Map<String, dynamic> model2Details;
  final String finalLabel; // The label from ModelService

  AnalysisResult({
    required this.videoName,
    required this.videoPath,
    required this.duration,
    required this.totalFrames,
    required this.fakeFrames,
    required this.originalFrames,
    required this.confidenceScore,
    required this.modelScores,
    required this.fakeSegments,
    required this.timestamp,
    required this.detailedReport,
    required this.model1Details,
    required this.model2Details,
    required this.finalLabel,
  });

  // FIXED: Convert ModelService result to AnalysisResult
  factory AnalysisResult.fromModelService({
    required Map<String, dynamic> modelResult,
    required String videoPath, // videoPath is in video_info, but pass as fallback
  }) {
    // Extract video info
    final videoInfo = modelResult['video_info'] ?? {};
    final videoFileName =
        videoInfo['file_name'] ?? videoPath.split('/').last;
    // Use duration from info, format to string
    final durationInSeconds = videoInfo['duration_seconds'] ?? 0;
    final videoDuration = '${durationInSeconds}s';

    // Get frame statistics from the model result
    final totalFrames = modelResult['total_frames'] ?? 0;
    final fakeFramesModel1 = modelResult['fake_frames_model1'] ?? 0;
    final fakeFramesModel2 = modelResult['fake_frames_model2'] ?? 0;
    final validFramesModel1 = modelResult['valid_frames_model1'] ?? 0;
    final validFramesModel2 = modelResult['valid_frames_model2'] ?? 0;

    // Use the label directly from the model service
    final String finalLabel = modelResult['final_label'] ?? 'INCONCLUSIVE';

    // Calculate overall fake frames (using average or max is a choice)
    // Let's use the logic from your original code (max)
    final fakeFrames =
        fakeFramesModel1 > fakeFramesModel2 ? fakeFramesModel1 : fakeFramesModel2;
    final originalFrames = totalFrames - fakeFrames;

    // Get confidence scores and convert to percentage
    double model1Confidence = (modelResult['model1_confidence'] ?? 0.0) * 100;
    double model2Confidence = (modelResult['model2_confidence'] ?? 0.0) * 100;
    // **FIX:** Use 'combined_confidence' key
    double combinedConfidence =
        (modelResult['combined_confidence'] ?? 0.0) * 100;

    // Calculate ratios
    final double fakeRatio1 =
        validFramesModel1 > 0 ? (fakeFramesModel1 / validFramesModel1) : 0.0;
    final double fakeRatio2 =
        validFramesModel2 > 0 ? (fakeFramesModel2 / validFramesModel2) : 0.0;

    // Create fake segments (this logic is a placeholder, as noted in your code)
    List<Map<String, String>> fakeSegments = _generateFakeSegments(
      fakeFramesModel1,
      fakeFramesModel2,
      totalFrames,
      videoDuration,
    );

    // Create model details
    Map<String, dynamic> model1Details = {
      'confidence': model1Confidence,
      'fake_frames': fakeFramesModel1,
      // **FIX:** Use 'valid_frames_model1' key
      'total_frames': validFramesModel1,
      'original_frames': validFramesModel1 - fakeFramesModel1,
      'fake_ratio': fakeRatio1,
      // 'frames_used' isn't in the map, so we use valid_frames
      'frames_used': validFramesModel1,
    };

    Map<String, dynamic> model2Details = {
      'confidence': model2Confidence,
      'fake_frames': fakeFramesModel2,
      // **FIX:** Use 'valid_frames_model2' key
      'total_frames': validFramesModel2,
      'original_frames': validFramesModel2 - fakeFramesModel2,
      'fake_ratio': fakeRatio2,
      // 'frames_used' isn't in the map, so we use valid_frames
      'frames_used': validFramesModel2,
    };

    // Create model scores
    Map<String, double> modelScores = {
      'Custom CNN Analysis': model1Confidence,
      'MobileNetV2 Ensemble': model2Confidence,
    };

    // Generate detailed report
    String detailedReport = _generateDetailedReport(
      videoFileName,
      videoDuration,
      DateTime.now().toString(),
      model1Confidence,
      model2Confidence,
      combinedConfidence,
      fakeFrames,
      originalFrames,
      totalFrames,
      finalLabel, // Use the label from the service
      fakeFramesModel1,
      validFramesModel1, // Pass valid frames
      fakeFramesModel2,
      validFramesModel2, // Pass valid frames
      fakeSegments,
      model1Details,
      model2Details,
    );

    return AnalysisResult(
      videoName: videoFileName,
      videoPath: videoInfo['path'] ?? videoPath,
      duration: videoDuration,
      totalFrames: totalFrames,
      fakeFrames: fakeFrames,
      originalFrames: originalFrames,
      confidenceScore: combinedConfidence,
      modelScores: modelScores,
      fakeSegments: fakeSegments,
      timestamp: DateTime.now(),
      detailedReport: detailedReport,
      model1Details: model1Details,
      model2Details: model2Details,
      finalLabel: finalLabel, // Store the label from the service
    );
  }

  // This function is no longer needed as we take the label from ModelService
  /*
  static String _determineFinalLabel(
    bool isFake, 
    double confidence, 
    double fakeRatio1, 
    double fakeRatio2
  ) { ... }
  */

  static List<Map<String, String>> _generateFakeSegments(
    int fakeFramesModel1,
    int fakeFramesModel2,
    int totalFrames,
    String duration,
  ) {
    if (fakeFramesModel1 == 0 && fakeFramesModel2 == 0) {
      return [];
    }
    if (totalFrames == 0) return []; // Avoid divide by zero

    List<Map<String, String>> segments = [];

    // Parse duration to get total seconds
    int totalSeconds = 0;
    try {
      totalSeconds = int.tryParse(duration.replaceAll('s', '')) ?? 0;
    } catch (e) {
      totalSeconds = 30; // Fallback
    }

    // Create segments based on fake frame distribution
    // For simplicity, create one segment representing the entire video
    // with manipulation indication
    if (fakeFramesModel1 > 0 || fakeFramesModel2 > 0) {
      double fakeRatio =
          ((fakeFramesModel1 + fakeFramesModel2) / 2) / totalFrames;

      if (fakeRatio > 0.7) {
        segments.add({
          'start': '00:00',
          'end': _formatTime(totalSeconds.toDouble()),
          'duration': '${totalSeconds}s',
          'confidence': 'High',
          'description': 'Widespread manipulation detected throughout video',
        });
      } else if (fakeRatio > 0.3) {
        segments.add({
          'start': '00:00',
          'end': _formatTime(totalSeconds.toDouble()),
          'duration': '${totalSeconds}s',
          'confidence': 'Medium',
          'description': 'Multiple manipulated segments detected',
        });
      } else {
        segments.add({
          'start': '00:00',
          'end': _formatTime(totalSeconds.toDouble()),
          'duration': '${totalSeconds}s',
          'confidence': 'Low',
          'description': 'Sporadic manipulation detected',
        });
      }
    }

    return segments;
  }

  static String _formatTime(double seconds) {
    int mins = (seconds ~/ 60);
    int secs = (seconds % 60).toInt();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static String _generateDetailedReport(
    String videoName,
    String duration,
    String analysisDate,
    double model1Confidence,
    double model2Confidence,
    double combinedConfidence,
    int fakeFrames,
    int originalFrames,
    int totalFrames,
    String finalLabel,
    int fakeFramesModel1,
    int totalFramesModel1,
    int fakeFramesModel2,
    int totalFramesModel2,
    List<Map<String, String>> fakeSegments,
    Map<String, dynamic> model1Details,
    Map<String, dynamic> model2Details,
  ) {
    StringBuffer report = StringBuffer();

    report.writeln('DEEPFAKE ANALYSIS REPORT');
    report.writeln('========================');
    report.writeln('Video: $videoName');
    report.writeln('Duration: $duration');
    report.writeln('Analysis Date: $analysisDate');
    report.writeln('');

    report.writeln('OVERALL RESULT:');
    report.writeln('• Final Label: $finalLabel');
    report.writeln(
        '• Combined Confidence: ${combinedConfidence.toStringAsFixed(1)}%');
    report.writeln('• Total Frames Analyzed: $totalFrames');
    report.writeln('');

    report.writeln('MODEL 1 (Custom CNN Analysis):');
    report.writeln('• Confidence: ${model1Confidence.toStringAsFixed(1)}%');
    report.writeln(
        '• Fake Frames: $fakeFramesModel1/$totalFramesModel1'); // Use passed total
    report.writeln('• Original Frames: ${model1Details['original_frames']}');
    report.writeln(
        '• Fake Frame Ratio: ${(model1Details['fake_ratio'] * 100).toStringAsFixed(1)}%');
    report.writeln('• Frames Used: ${model1Details['frames_used']}');
    report.writeln('');

    report.writeln('MODEL 2 (MobileNetV2 Ensemble):');
    report.writeln('• Confidence: ${model2Confidence.toStringAsFixed(1)}%');
    report.writeln(
        '• Fake Frames: $fakeFramesModel2/$totalFramesModel2'); // Use passed total
    report.writeln('• Original Frames: ${model2Details['original_frames']}');
    report.writeln(
        '• Fake Frame Ratio: ${(model2Details['fake_ratio'] * 100).toStringAsFixed(1)}%');
    report.writeln('• Frames Used: ${model2Details['frames_used']}');
    report.writeln('');

    report.writeln('COMBINED FRAME ANALYSIS:');
    report.writeln('• Total Frames Processed: $totalFrames');
    report.writeln('• AI-Edited Frames Detected: $fakeFrames');
    report.writeln('• Original Frames: $originalFrames');
    final manipulationRatio = totalFrames > 0 ? (fakeFrames / totalFrames) * 100 : 0.0;
    report.writeln(
        '• Manipulation Ratio: ${manipulationRatio.toStringAsFixed(1)}%');
    report.writeln('');

    report.writeln('DETECTION SEGMENTS:');
    if (fakeSegments.isEmpty) {
      report.writeln('• No specific AI-edited segments identified');
      report.writeln('• Analysis indicates consistent video characteristics');
    } else {
      for (int i = 0; i < fakeSegments.length; i++) {
        final segment = fakeSegments[i];
        report.writeln(
            '• Segment ${i + 1}: ${segment['start']} - ${segment['end']} (${segment['duration']})');
        report.writeln(
            '  Confidence: ${segment['confidence']} - ${segment['description']}');
      }
    }

    report.writeln('');
    report.writeln('ANALYSIS METHODOLOGY:');
    report.writeln('• Dual-model consensus analysis performed');
    report.writeln('• $totalFrames frames extracted and processed');
    report.writeln('• Facial artifact detection using Custom CNN');
    report.writeln(
        '• Feature consistency analysis using MobileNetV2 Ensemble');
    report.writeln('• Frame-by-frame deep learning inference');
    report.writeln('• Cross-model validation and confidence scoring');
    report.writeln('');

    report.writeln('TECHNICAL DETAILS:');
    report.writeln('• Model 1: Custom CNN for facial swapping artifacts');
    report.writeln(
        '• Model 2: MobileNetV2 Ensemble for digital inconsistencies');
    report.writeln('• Input Resolution: 224x224 pixels');
    report.writeln('• Processing: Frame-level inference with ensemble voting');
    report.writeln('• Confidence Threshold: >40% for fake detection');
    report.writeln('');

    report.writeln('RECOMMENDATION:');
    // Base recommendation on the label from the service
    if (finalLabel == 'LIKELY DEEPFAKE') {
      report.writeln('⚠️ STRONG INDICATION OF MANIPULATION');
      report.writeln(
          '  This content shows significant signs of AI manipulation.');
      report.writeln(
          '  Verify authenticity through additional sources before sharing.');
    } else if (finalLabel == 'POSSIBLY MANIPULATED') {
      report.writeln('⚠️ MODERATE INDICATION OF MANIPULATION');
      report.writeln('  Some manipulation detected. Exercise caution when sharing.');
      report.writeln(
          '  Consider additional verification for critical use cases.');
    } else {
      report.writeln('✅ CONTENT APPEARS AUTHENTIC');
      report.writeln('  Minimal signs of AI manipulation detected.');
      report.writeln('  Content shows consistent natural characteristics.');
    }

    report.writeln('');
    report.writeln('END OF REPORT');
    report.writeln('=============');

    return report.toString();
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'videoName': videoName,
      'videoPath': videoPath,
      'duration': duration,
      'totalFrames': totalFrames,
      'fakeFrames': fakeFrames,
      'originalFrames': originalFrames,
      'confidenceScore': confidenceScore,
      'modelScores': modelScores,
      'fakeSegments': fakeSegments,
      'timestamp': timestamp.toIso8601String(),
      'detailedReport': detailedReport,
      'model1Details': model1Details,
      'model2Details': model2Details,
      'finalLabel': finalLabel,
    };
  }

  // FIXED: Create from map
  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    return AnalysisResult(
      videoName: map['videoName'],
      videoPath: map['videoPath'],
      duration: map['duration'],
      totalFrames: map['totalFrames'],
      fakeFrames: map['fakeFrames'],
      originalFrames: map['originalFrames'],
      confidenceScore: map['confidenceScore'],
      modelScores: Map<String, double>.from(map['modelScores']),
      // **FIX:** Properly parse the list of maps
      fakeSegments: (map['fakeSegments'] as List)
          .map((segment) => Map<String, String>.from(segment as Map))
          .toList(),
      timestamp: DateTime.parse(map['timestamp']),
      detailedReport: map['detailedReport'],
      model1Details: Map<String, dynamic>.from(map['model1Details']),
      model2Details: Map<String, dynamic>.from(map['model2Details']),
      finalLabel: map['finalLabel'],
    );
  }

  // Convert to JSON string
  String toJson() {
    return json.encode(toMap());
  }

  // Create from JSON string
  factory AnalysisResult.fromJson(String jsonString) {
    return AnalysisResult.fromMap(json.decode(jsonString));
  }

  // Helper method to get display-friendly confidence text
  String get confidenceText {
    if (confidenceScore > 80) return 'Very High';
    if (confidenceScore > 60) return 'High';
    if (confidenceScore > 40) return 'Moderate';
    if (confidenceScore > 20) return 'Low';
    return 'Very Low';
  }

  // FIXED: Helper method to get Color object
  Color get confidenceColor {
    if (finalLabel == 'LIKELY DEEPFAKE') {
      return Colors.red;
    } else if (finalLabel == 'POSSIBLY MANIPULATED') {
      return Colors.orange;
    } else {
      // LIKELY AUTHENTIC
      return Colors.green;
    }
  }
}