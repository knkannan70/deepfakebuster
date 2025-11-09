import 'package:flutter/material.dart';
import '../models/analysis_result.dart';

class ResultsCard extends StatelessWidget {
  final AnalysisResult result;

  const ResultsCard({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with final result
              _buildResultHeader(),
              const SizedBox(height: 20),
              
              // Model Confidence Scores Section
              _buildSectionTitle('AI Model Analysis Results'),
              const SizedBox(height: 12),
              _buildModelScoresSection(),
              
              Divider(color: Colors.grey[700], height: 30),
              
              // Frame Analysis Section
              _buildSectionTitle('Frame-by-Frame Analysis'),
              const SizedBox(height: 12),
              _buildFrameAnalysisSection(),
              
              Divider(color: Colors.grey[700], height: 30),
              
              // Video Information
              _buildSectionTitle('Video Information'),
              const SizedBox(height: 12),
              _buildVideoInfoSection(),
              
              // Fake Segments
              if (result.fakeSegments.isNotEmpty) ...[
                Divider(color: Colors.grey[700], height: 30),
                const SizedBox(height: 10),
                _buildSectionTitle('AI-Edited Segments Detected'),
                const SizedBox(height: 12),
                ...result.fakeSegments.map((segment) => 
                  _buildSegmentCard(segment)
                ).toList(),
              ],
              
              // Detailed Report Section
              Divider(color: Colors.grey[700], height: 30),
              _buildSectionTitle('Detailed Technical Report'),
              const SizedBox(height: 12),
              _buildDetailedReportSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader() {
    final isFake = result.finalLabel.contains('FAKE');
    final headerColor = isFake ? Colors.red : Colors.green;
    final icon = isFake ? Icons.warning : Icons.verified;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [headerColor.withOpacity(0.2), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: headerColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.finalLabel,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: headerColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${result.confidenceScore.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelScoresSection() {
    // Convert model details to proper types with safe casting
    final model1Confidence = _safeConvertToDouble(result.model1Details['confidence']);
    final model1FakeFrames = _safeConvertToInt(result.model1Details['fake_frames']);
    final model1TotalFrames = _safeConvertToInt(result.model1Details['total_frames']);
    
    final model2Confidence = _safeConvertToDouble(result.model2Details['confidence']);
    final model2FakeFrames = _safeConvertToInt(result.model2Details['fake_frames']);
    final model2TotalFrames = _safeConvertToInt(result.model2Details['total_frames']);

    return Column(
      children: [
        // Model 1 Details
        _buildModelDetailCard(
          'Custom CNN Analysis',
          model1Confidence,
          model1FakeFrames,
          model1TotalFrames,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        
        // Model 2 Details
        _buildModelDetailCard(
          'MobileNetV2 Ensemble',
          model2Confidence,
          model2FakeFrames,
          model2TotalFrames,
          Colors.purple,
        ),
        const SizedBox(height: 16),
        
        // Combined Confidence
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology, color: Colors.amber, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Combined Confidence Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                '${result.confidenceScore.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelDetailCard(String modelName, double confidence, int fakeFrames, int totalFrames, Color color) {
    final fakeRatio = totalFrames > 0 ? (fakeFrames / totalFrames) * 100 : 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                modelName,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${confidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fake Frames: $fakeFrames/$totalFrames',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Text(
                '${fakeRatio.toStringAsFixed(1)}% fake',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: fakeRatio / 100,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameAnalysisSection() {
  // Convert to double explicitly
  final fakePercentage = result.totalFrames > 0 ? (result.fakeFrames / result.totalFrames) * 100 : 0.0;
  final originalPercentage = result.totalFrames > 0 ? (result.originalFrames / result.totalFrames) * 100 : 0.0;
  
  return Column(
    children: [
      // Frame Distribution Chart
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Frame Distribution Analysis',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            
            // Progress bars - explicitly cast to double
            _buildFrameDistributionBar('AI-Edited Frames', fakePercentage.toDouble(), Colors.red),
            const SizedBox(height: 8),
            _buildFrameDistributionBar('Original Frames', originalPercentage.toDouble(), Colors.green),
            const SizedBox(height: 12),
            
            // Statistics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Frames', '${result.totalFrames}', Icons.collections),
                _buildStatItem('AI-Edited', '${result.fakeFrames}', Icons.warning),
                _buildStatItem('Original', '${result.originalFrames}', Icons.verified),
              ],
            ),
          ],
        ),
      ),
      
      const SizedBox(height: 16),
      
      // Analysis Summary
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getAnalysisColor().withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              _getAnalysisIcon(),
              color: _getAnalysisColor(),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getAnalysisSummary(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildFrameDistributionBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[700],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
      ],
    );
  }

  Widget _buildVideoInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow('Video File', result.videoName, Icons.video_file),
          _buildInfoRow('Duration', result.duration, Icons.timer),
          _buildInfoRow('Analysis Date', _formatDate(result.timestamp), Icons.calendar_today),
          _buildInfoRow('Total Frames', '${result.totalFrames} frames', Icons.collections),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey[400])),
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(Map<String, String> segment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timelapse, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${segment['start']} - ${segment['end']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (segment['duration'] != null)
                  Text(
                    'Duration: ${segment['duration']}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                if (segment['confidence'] != null)
                  Text(
                    'Confidence: ${segment['confidence']}',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedReportSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Technical Analysis Summary',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.detailedReport,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  // Helper methods for safe type conversion
  double _safeConvertToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return 0.0;
  }

  int _safeConvertToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return 0;
  }

  // Helper methods for styling
  Color _getAnalysisColor() {
    if (result.finalLabel.contains('FAKE')) {
      return result.confidenceScore > 70 ? Colors.red : Colors.orange;
    } else {
      return result.confidenceScore > 80 ? Colors.green : Colors.blue;
    }
  }

  IconData _getAnalysisIcon() {
    if (result.finalLabel.contains('FAKE')) {
      return Icons.warning;
    } else {
      return Icons.verified;
    }
  }

  String _getAnalysisSummary() {
    if (result.finalLabel.contains('HIGH CONFIDENCE FAKE')) {
      return 'Strong indicators of AI manipulation detected across multiple frames with high confidence.';
    } else if (result.finalLabel.contains('LIKELY FAKE')) {
      return 'Moderate indicators of AI manipulation detected. Further verification recommended.';
    } else if (result.finalLabel.contains('POSSIBLY FAKE')) {
      return 'Some signs of manipulation detected but with lower confidence.';
    } else if (result.finalLabel.contains('HIGH CONFIDENCE REAL')) {
      return 'Content appears authentic with minimal signs of manipulation.';
    } else if (result.finalLabel.contains('LIKELY REAL')) {
      return 'Content shows characteristics of authentic video with minor inconsistencies.';
    } else {
      return 'Analysis results are inconclusive. Consider re-analyzing with different settings.';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}