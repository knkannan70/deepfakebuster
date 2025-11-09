import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/analysis_result.dart';
import '../widgets/results_card.dart';
import 'history_screen.dart';
import '../models/model_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedVideo;
  VideoPlayerController? _controller;
  bool _isAnalyzing = false;
  AnalysisResult? _analysisResult;
  static List<AnalysisResult> historyItems = [];
  bool _showInstructions = true;
  bool _cancelAnalysis = false;
  double _extractionProgress = 0.0;
  Map<String, dynamic>? _currentVideoInfo; // <-- FIX 1: Added state variable

  // Model analysis states
  bool _model1Loaded = false;
  bool _model2Loaded = false;
  double _model1Score = 0.0;
  double _model2Score = 0.0;
  int _totalFramesProcessed = 0;
  int _fakeFramesCountModel1 = 0;
  int _fakeFramesCountModel2 = 0;

  // Model service
  final ModelService _modelService = ModelService();

  // Access analysis results
  Map<String, dynamic>? get _lastAnalysisResult =>
      _modelService.lastAnalysisResult;
  Map<String, String>? get _formattedResults =>
      _modelService.getFormattedResults();

  // Display video info (This is from the *last completed* analysis)
  Map<String, dynamic>? get _videoInfo => _lastAnalysisResult?['video_info'];

  // Show analysis history
  List<String> get _analysisHistory => _modelService.analysisHistory;

  // Track progress with frame counts
  int get _frames1 => _modelService.framesUsedModel1;
  int get _frames2 => _modelService.framesUsedModel2;

  @override
  void initState() {
    super.initState();
    _initializeModels();
  }

  Future<void> _initializeModels() async {
    try {
      await _modelService.initializeModels();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading models: $e');
      _showErrorDialog('Failed to load AI models: $e');
    }
  }

  // FIX 2: Added helper function to get info when video is picked
  Future<Map<String, dynamic>?> _fetchVideoInfo(File videoFile) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose(); // Dispose *after* getting duration

      if (duration <= Duration.zero) {
        print("Warning: Video duration reported as zero or negative.");
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
      print('Failed to get video info from HomeScreen: $e');
      // Return null so the caller can handle it
      return null;
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile != null) {
        // Check video duration first
        final videoFile = File(pickedFile.path);
        final duration = await _getVideoDuration(videoFile.path);

        if (duration.inSeconds > 60) {
          _showErrorDialog(
            'Please upload a video below 1 minute. Selected video is ${duration.inSeconds} seconds.',
          );
          return;
        }

        // Test if video can be played before proceeding
        final testController = VideoPlayerController.file(videoFile);

        try {
          await testController.initialize();
          // If we reach here, video is compatible
          await testController.dispose();
        } catch (e) {
          await testController.dispose();
          _showErrorDialog(
            'This video format is not supported. Please try a different video with standard MP4 format (H.264 codec recommended).',
          );
          return; // Exit here to prevent selecting incompatible video
        }

        // FIX 3: Fetch full info *after* validation
        final videoInfo = await _fetchVideoInfo(videoFile);
        if (videoInfo == null) {
          _showErrorDialog(
              'Could not read video file details. Please try again.');
          return;
        }

        // Only proceed if video is compatible
        await _controller?.dispose();

        setState(() {
          _selectedVideo = videoFile;
          _currentVideoInfo = videoInfo; // *** STORE THE INFO ***
          _analysisResult = null;
          _model1Loaded = false;
          _model2Loaded = false;
          _model1Score = 0.0;
          _model2Score = 0.0;
          _showInstructions = true;
          _cancelAnalysis = false;
          _extractionProgress = 0.0;
          _totalFramesProcessed = 0;
          _fakeFramesCountModel1 = 0;
          _fakeFramesCountModel2 = 0;
        });

        _controller = VideoPlayerController.file(_selectedVideo!)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
            }
          })
          ..addListener(() {
            if (mounted) {
              setState(() {});
            }
          });
      }
    } catch (e) {
      _showErrorDialog('Error picking video: $e');
    }
  }

  Future<Duration> _getVideoDuration(String videoPath) async {
    final controller = VideoPlayerController.file(File(videoPath));

    await controller.initialize();

    // Wait until duration becomes non-zero (max 2 seconds)
    int retries = 0;
    while (controller.value.duration == Duration.zero && retries < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }

    final duration = controller.value.duration;
    await controller.dispose();

    return duration;
  }

  // <-- LOGIC APPLIED: This method is refactored to use the 'finally'
  //     pattern from VideoAnalysisScreen.dart for cleaner state management.
  Future<void> _analyzeVideo() async {
    if (_selectedVideo == null) return;
    if (!_modelService.areModelsInitialized) {
      _showErrorDialog('AI models are not loaded yet. Please wait.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _model1Loaded = false;
      _model2Loaded = false;
      _analysisResult = null;
      _model1Score = 0.0;
      _model2Score = 0.0;
      _showInstructions = false;
      _cancelAnalysis = false;
      _extractionProgress = 0.0;
      _totalFramesProcessed = 0;
      _fakeFramesCountModel1 = 0;
      _fakeFramesCountModel2 = 0;
    });

    try {
      // Set up progress callback
      _modelService.setProgressCallback((progress) {
        if (mounted && !_cancelAnalysis) {
          setState(() {
            _extractionProgress = progress;
          });
        }
      });

      // Use ModelService's analyzeVideo method which returns properly formatted results
      Map<String, dynamic> rawResult = await _modelService.analyzeVideo(
        _selectedVideo!.path,
      );

      if (_cancelAnalysis) return;

      // Convert to AnalysisResult using the factory constructor
      AnalysisResult result = AnalysisResult.fromModelService(
        modelResult: rawResult,
        videoPath: _selectedVideo!.path,
      );

      // Update state with actual model results using the integrated getters
      setState(() {
        _model1Loaded = true;
        _model2Loaded = true;
        _model1Score = (rawResult['model1_confidence'] ?? 0.0) * 100;
        _model2Score = (rawResult['model2_confidence'] ?? 0.0) * 100;
        _fakeFramesCountModel1 = rawResult['fake_frames_model1'] ?? 0;
        _fakeFramesCountModel2 = rawResult['fake_frames_model2'] ?? 0;
        _totalFramesProcessed = rawResult['total_frames'] ?? 0;
      });

      await _saveToHistory(result);

      if (mounted && !_cancelAnalysis) {
        setState(() {
          _analysisResult = result;
          // _isAnalyzing = false; <-- Removed from here
        });
      }
    } catch (e) {
      print('Analysis error: $e');
      if (mounted && !_cancelAnalysis) {
        setState(() {
          // _isAnalyzing = false; <-- Removed from here
          _showInstructions = true;
        });
        _showErrorDialog('Analysis failed: $e');
      }
    } finally {
      // <-- ADDED: This block is applied from VideoAnalysisScreen's logic
      //     to ensure _isAnalyzing is always reset.
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _extractionProgress = 0.0;
        });
      }
    }
  }

  void _cancelAnalysisProcess() {
    setState(() {
      _cancelAnalysis = true;
      _isAnalyzing = false;
      _extractionProgress = 0.0;
    });
    _modelService.cancelAnalysis();
  }

  Future<void> _saveToHistory(AnalysisResult result) async {
    historyItems.insert(0, result);
    if (historyItems.length > 50) {
      historyItems = historyItems.sublist(0, 50);
    }
  }

  Widget _buildModelLoadingStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.analytics, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Text(
                  'AI Model Analysis Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // FIX 4: Use _currentVideoInfo here
          // Video info display if available
          if (_currentVideoInfo != null && _isAnalyzing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade800),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Video Information',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'File: ${_currentVideoInfo?['file_name'] ?? 'N/A'}\n'
                          'Size: ${_currentVideoInfo?['file_size_mb'] ?? 'N/A'} MB | '
                          'Duration: ${_currentVideoInfo?['duration_seconds'] ?? 'N/A'}s',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // FIX 4: Use _currentVideoInfo here
          if (_currentVideoInfo != null && _isAnalyzing) const SizedBox(height: 16),

          // Frame extraction progress
          if (_extractionProgress > 0 && _extractionProgress < 1)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade800,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.collections,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Extracting Video Frames',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(_extractionProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _extractionProgress,
                    backgroundColor: Colors.grey.shade800,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Frames: $_totalFramesProcessed',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Model 1: $_frames1 | Model 2: $_frames2',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (_extractionProgress > 0 && _extractionProgress < 1)
            const SizedBox(height: 16),

          _buildModelStatus(
            'Custom CNN Analysis',
            _model1Loaded,
            _model1Score,
            _fakeFramesCountModel1,
            _frames1,
          ),
          const SizedBox(height: 12),
          _buildModelStatus(
            'MobileNetV2 Ensemble',
            _model2Loaded,
            _model2Score,
            _fakeFramesCountModel2,
            _frames2,
          ),
          const SizedBox(height: 20),

          // Analysis history preview
          if (_analysisHistory.isNotEmpty && _isAnalyzing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade800),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.purple, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Analysis History',
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_analysisHistory.length} previous analyses stored',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_analysisHistory.isNotEmpty && _isAnalyzing) const SizedBox(height: 16),

          // Final analysis result
          if (_model1Loaded && _model2Loaded && _analysisResult != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _getResultGradientColors(),
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getResultBorderColor()),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getResultIcon(), color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Final Analysis: ${_analysisResult!.finalLabel}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Confidence: ${_analysisResult!.confidenceScore.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Formatted results preview
          if (_formattedResults != null && _analysisResult != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade800),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detailed Report Available',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap results card for complete analysis',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (_formattedResults!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Status: ${_formattedResults!['status']}',
                            style: TextStyle(
                              color: Colors.orange.shade300,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (_formattedResults != null && _analysisResult != null)
            const SizedBox(height: 16),

          const SizedBox(height: 20),

          // Cancel button during analysis
          if (_isAnalyzing)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cancelAnalysisProcess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                  shadowColor: Colors.red.withOpacity(0.4),
                ),
                child: const Text(
                  'Cancel Analysis Process',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods for result styling
  List<Color> _getResultGradientColors() {
    if (_analysisResult == null) return [Colors.grey.shade800, Colors.black];

    if (_analysisResult!.finalLabel.contains('FAKE')) {
      if (_analysisResult!.confidenceScore > 70) {
        return [Colors.red.shade800, Colors.black];
      } else {
        return [Colors.orange.shade800, Colors.black];
      }
    } else {
      if (_analysisResult!.confidenceScore > 80) {
        return [Colors.green.shade800, Colors.black];
      } else {
        return [Colors.blue.shade800, Colors.black];
      }
    }
  }

  Color _getResultBorderColor() {
    if (_analysisResult == null) return Colors.grey;

    if (_analysisResult!.finalLabel.contains('FAKE')) {
      if (_analysisResult!.confidenceScore > 70) {
        return Colors.red;
      } else {
        return Colors.orange;
      }
    } else {
      if (_analysisResult!.confidenceScore > 80) {
        return Colors.green;
      } else {
        return Colors.blue;
      }
    }
  }

  IconData _getResultIcon() {
    if (_analysisResult == null) return Icons.help_outline;

    if (_analysisResult!.finalLabel.contains('FAKE')) {
      return Icons.warning;
    } else {
      return Icons.verified;
    }
  }

  Widget _buildModelStatus(
    String modelName,
    bool isLoaded,
    double score,
    int fakeFrames,
    int totalFrames,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLoaded ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isLoaded ? Colors.green : Colors.orange).withOpacity(
                    0.5,
                  ),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isLoaded ? Icons.check : Icons.schedule,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modelName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fake Frames: $fakeFrames / $totalFrames',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: isLoaded ? (score / 100) : null,
                  backgroundColor: Colors.grey.shade800,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isLoaded
                        ? (score > 70
                            ? Colors.red
                            : score > 40
                                ? Colors.orange
                                : Colors.green)
                        : Colors.orange,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isLoaded
                  ? (score > 70
                      ? Colors.red.withOpacity(0.2)
                      : score > 40
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2))
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLoaded
                    ? (score > 70
                        ? Colors.red
                        : score > 40
                            ? Colors.orange
                            : Colors.green)
                    : Colors.orange,
                width: 2,
              ),
            ),
            child: Text(
              isLoaded ? '${score.toStringAsFixed(1)}%' : 'Processing',
              style: TextStyle(
                color: isLoaded
                    ? (score > 70
                        ? Colors.red
                        : score > 40
                            ? Colors.orange
                            : Colors.green)
                    : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade900, Colors.black],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Deepfake Detection Guide',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            _buildInstructionStep(
              number: 1,
              title: 'Select Video File',
              description:
                  'Choose a video file from your device gallery. Supported formats include MP4, MOV, and AVI. Maximum duration: 1 minute.',
              icon: Icons.video_file,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: 2,
              title: 'Preview Video Content',
              description:
                  'Review the selected video using the built-in player. Ensure the video contains clear facial content for accurate analysis.',
              icon: Icons.play_arrow,
              color: Colors.red.shade700,
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: 3,
              title: 'Initiate AI Analysis',
              description:
                  'Start the deepfake detection process. Our dual AI model system will analyze facial features and video artifacts frame by frame.',
              icon: Icons.psychology,
              color: Colors.red.shade600,
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: 4,
              title: 'Monitor Analysis Progress',
              description:
                  'Track real-time progress as both AI models process the video. Frame extraction and model inference are displayed separately.',
              icon: Icons.monitor_heart,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: 5,
              title: 'Review Detection Report',
              description:
                  'Receive comprehensive analysis results including confidence scores, frame-level detection, and detailed technical insights.',
              icon: Icons.analytics,
              color: Colors.green,
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Optimization Guidelines',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildTipChip('Clear facial visibility'),
                      _buildTipChip('Good lighting conditions'),
                      _buildTipChip('Stable camera footage'),
                      _buildTipChip('10-60 second duration'),
                      _buildTipChip('High resolution video'),
                      _buildTipChip('Front-facing angles'),
                      _buildTipChip('Minimal motion blur'),
                      _buildTipChip('Standard video formats'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'For optimal detection accuracy, ensure videos feature clear, well-lit faces with minimal movement and compression artifacts.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.green.shade800, Colors.black],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.security, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Technology Overview',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Our detection system employs two specialized AI models:\n\n'
                    '• Custom CNN: Analyzes facial swapping artifacts and manipulation patterns\n'
                    '• MobileNetV2 Ensemble: Detects compression artifacts and digital inconsistencies\n\n'
                    'Combined analysis provides comprehensive deepfake detection with high accuracy.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required int number,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_analysisResult == null) {
      return _buildInstructionsSection();
    } else {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getResultGradientColors(),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              boxShadow: [
                BoxShadow(
                  color: _getResultBorderColor().withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getResultIcon(), color: Colors.white, size: 28),
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Analysis Complete',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _analysisResult!.finalLabel,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                child: ResultsCard(result: _analysisResult!),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildVideoPreviewSection() {
    return Semantics(
      label: 'Video preview section',
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: _selectedVideo == null
              ? _buildEmptyState()
              : _controller != null && _controller!.value.isInitialized
                  ? _buildVideoPlayer()
                  : _buildLoadingState(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade900, Colors.black],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.video_library, size: 36, color: Colors.red),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Video Selected',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Select a video file to begin deepfake analysis',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Supported formats: MP4, MOV, AVI • Max duration: 1 minute',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade900, Colors.black],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading Video File',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Initializing video player',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        VideoPlayer(_controller!),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.red,
            onPressed: () {
              setState(() {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
              });
            },
            child: Icon(
              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _controller!.value.duration.toString().split('.')[0],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red),
                  ),
                  child:
                      const Icon(Icons.error_outline, color: Colors.red, size: 30),
                ),
                const SizedBox(height: 20),
                const Text(
                  'System Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: Colors.red.withOpacity(0.4),
                    ),
                    child: const Text(
                      'Acknowledge',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(() {});
    _controller?.pause();
    _controller?.dispose();
    _modelService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.security, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Deepfake Detection System',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 16 : 18,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.grey.shade900],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 24),
            onPressed: historyItems.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            HistoryScreen(historyItems: historyItems),
                      ),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.pushNamed(context, '/about');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Model loading indicator
              if (!_modelService.areModelsInitialized) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                        strokeWidth: 3,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Initializing AI Detection Models',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Loading neural network weights and configuration',
                              style: TextStyle(
                                color: Colors.orange.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Video preview section
              _buildVideoPreviewSection(),

              const SizedBox(height: 20),

              // Action buttons
              if (isSmallScreen)
                Column(
                  children: [
                    _buildActionButton(
                      onPressed: _pickVideo,
                      icon: Icons.video_file,
                      text: 'Select Video File',
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      onPressed: _selectedVideo == null ||
                              _isAnalyzing ||
                              !_modelService.areModelsInitialized
                          ? null
                          : _analyzeVideo,
                      icon: Icons.psychology,
                      text: _isAnalyzing
                          ? 'Processing Analysis...'
                          : 'Start Deepfake Analysis',
                      color: _selectedVideo == null ||
                              _isAnalyzing ||
                              !_modelService.areModelsInitialized
                          ? Colors.grey.shade800
                          : Colors.red.shade700,
                      isLoading: _isAnalyzing,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        onPressed: _pickVideo,
                        icon: Icons.video_file,
                        text: 'Select Video File',
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionButton(
                        onPressed: _selectedVideo == null ||
                                _isAnalyzing ||
                                !_modelService.areModelsInitialized
                            ? null
                            : _analyzeVideo,
                        icon: Icons.psychology,
                        text: _isAnalyzing
                            ? 'Processing Analysis...'
                            : 'Start Deepfake Analysis',
                        color: _selectedVideo == null ||
                                _isAnalyzing ||
                                !_modelService.areModelsInitialized
                            ? Colors.grey.shade800
                            : Colors.red.shade700,
                        isLoading: _isAnalyzing,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // ***--- FIX FOR RenderFlex OVERFLOW ---***
              // The entire bottom section is now wrapped in one Expanded
              // widget. The content inside is then made scrollable if needed.
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isAnalyzing
                      ? SingleChildScrollView(
                          // Key to fix: Make the "in-progress" view scrollable
                          key: const ValueKey('analyzing'),
                          child: _buildModelLoadingStatus(),
                        )
                      : Container(
                          // Key to switch: The results/instructions view
                          key: const ValueKey('results'),
                          child: _buildResultsSection(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String text,
    required Color color,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: color.withOpacity(0.4),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}