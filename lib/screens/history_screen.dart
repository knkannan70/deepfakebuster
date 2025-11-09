import 'package:flutter/material.dart';
import '../models/analysis_result.dart';
import '../widgets/results_card.dart';

class HistoryScreen extends StatefulWidget {
  final List<AnalysisResult> historyItems;

  const HistoryScreen({Key? key, required this.historyItems}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<AnalysisResult> _displayedItems;
  String _sortBy = 'date';
  bool _ascending = false;
  String _filterBy = 'all';

  @override
  void initState() {
    super.initState();
    _displayedItems = List.from(widget.historyItems);
    _sortItems();
  }

  void _sortItems() {
    setState(() {
      _displayedItems.sort((a, b) {
        int comparison;
        switch (_sortBy) {
          case 'name':
            comparison = a.videoName.compareTo(b.videoName);
            break;
          case 'confidence':
            comparison = a.confidenceScore.compareTo(b.confidenceScore);
            break;
          case 'fakeFrames':
            comparison = a.fakeFrames.compareTo(b.fakeFrames);
            break;
          case 'duration':
            comparison = a.duration.compareTo(b.duration);
            break;
          case 'date':
          default:
            comparison = a.timestamp.compareTo(b.timestamp);
            break;
        }
        return _ascending ? comparison : -comparison;
      });
    });
  }

  void _filterItems() {
    setState(() {
      if (_filterBy == 'all') {
        _displayedItems = List.from(widget.historyItems);
      } else if (_filterBy == 'fake') {
        _displayedItems = widget.historyItems
            .where((item) => item.finalLabel.contains('FAKE'))
            .toList();
      } else if (_filterBy == 'real') {
        _displayedItems = widget.historyItems
            .where((item) => item.finalLabel.contains('REAL') || item.finalLabel.contains('AUTHENTIC'))
            .toList();
      } else if (_filterBy == 'high_confidence') {
        _displayedItems = widget.historyItems
            .where((item) => item.confidenceScore > 70)
            .toList();
      }
      _sortItems();
    });
  }

  void _deleteItem(int index) {
    final itemToDelete = _displayedItems[index];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Delete Analysis',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete the analysis for "${itemToDelete.videoName}"?',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.historyItems.remove(itemToDelete);
                  _displayedItems.removeAt(index);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('Analysis deleted successfully'),
                  ),
                );
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _clearAllHistory() {
    if (_displayedItems.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Clear All History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete all ${_displayedItems.length} analysis records? This action cannot be undone.',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  widget.historyItems.clear();
                  _displayedItems.clear();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text('All history cleared'),
                  ),
                );
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Color _getResultColor(AnalysisResult result) {
    if (result.finalLabel.contains('FAKE')) {
      if (result.confidenceScore > 70) return Colors.red;
      return Colors.orange;
    } else {
      if (result.confidenceScore > 80) return Colors.green;
      return Colors.blue;
    }
  }

  IconData _getResultIcon(AnalysisResult result) {
    if (result.finalLabel.contains('FAKE')) {
      return Icons.warning;
    } else {
      return Icons.verified;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        actions: [
          if (_displayedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: _clearAllHistory,
              tooltip: 'Clear All History',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                _filterBy = value;
                _filterItems();
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('All Analyses'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'fake',
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Fake Detections'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'real',
                child: Row(
                  children: [
                    Icon(Icons.verified, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Real Videos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'high_confidence',
                child: Row(
                  children: [
                    Icon(Icons.assessment, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('High Confidence'),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (value) {
              setState(() {
                if (value == 'toggle_order') {
                  _ascending = !_ascending;
                } else {
                  _sortBy = value;
                }
                _sortItems();
              });
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.date_range, size: 20),
                    SizedBox(width: 8),
                    Text('Sort by Date'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.title, size: 20),
                    SizedBox(width: 8),
                    Text('Sort by Name'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'confidence',
                child: Row(
                  children: [
                    Icon(Icons.assessment, size: 20),
                    SizedBox(width: 8),
                    Text('Sort by Confidence'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'fakeFrames',
                child: Row(
                  children: [
                    Icon(Icons.warning, size: 20),
                    SizedBox(width: 8),
                    Text('Sort by Fake Frames'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'duration',
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 20),
                    SizedBox(width: 8),
                    Text('Sort by Duration'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'toggle_order',
                child: Row(
                  children: [
                    Icon(
                      _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(_ascending ? 'Ascending' : 'Descending'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[850],
        child: _displayedItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off,
                      size: 80,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filterBy == 'all' 
                          ? 'No Analysis History'
                          : 'No Matching Analyses',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _filterBy == 'all'
                          ? 'Your video analyses will appear here'
                          : 'Try changing your filter settings',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    if (_filterBy != 'all') ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filterBy = 'all';
                            _filterItems();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Show All Analyses'),
                      ),
                    ],
                  ],
                ),
              )
            : Column(
                children: [
                  // Filter and sort info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey[800],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_displayedItems.length} analysis${_displayedItems.length == 1 ? '' : 'es'}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        if (_filterBy != 'all')
                          Text(
                            'Filter: ${_getFilterLabel(_filterBy)}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _displayedItems.length,
                      itemBuilder: (context, index) {
                        final item = _displayedItems[index];
                        final resultColor = _getResultColor(item);
                        final resultIcon = _getResultIcon(item);
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: resultColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HistoryDetailScreen(result: item),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Result Icon
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: resultColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: resultColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Icon(
                                        resultIcon,
                                        color: resultColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Analysis Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.videoName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.grey[500],
                                                ),
                                                onPressed: () => _deleteItem(index),
                                                iconSize: 20,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${_formatDate(item.timestamp)} • ${item.duration}',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildStatChip(
                                                item.finalLabel,
                                                resultColor,
                                              ),
                                              const SizedBox(width: 8),
                                              _buildStatChip(
                                                '${item.confidenceScore.toStringAsFixed(1)}%',
                                                _getConfidenceColor(item.confidenceScore),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildStatChip(
                                                'Frames: ${item.fakeFrames}/${item.totalFrames}',
                                                Colors.grey,
                                              ),
                                              const SizedBox(width: 8),
                                              if (item.modelScores.isNotEmpty)
                                                _buildStatChip(
                                                  'Model 1: ${item.modelScores['Custom CNN Analysis']?.toStringAsFixed(1) ?? '0.0'}%',
                                                  Colors.blue,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey[600],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 80) return Colors.green;
    if (confidence > 60) return Colors.blue;
    if (confidence > 40) return Colors.orange;
    return Colors.red;
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'fake': return 'Fake Detections';
      case 'real': return 'Real Videos';
      case 'high_confidence': return 'High Confidence';
      default: return 'All';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _truncatePath(String path) {
    if (path.length <= 30) return path;
    return '...${path.substring(path.length - 30)}';
  }
}

class HistoryDetailScreen extends StatelessWidget {
  final AnalysisResult result;

  const HistoryDetailScreen({Key? key, required this.result}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Details', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // Share functionality would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share functionality coming soon'),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[850],
        child: Column(
          children: [
            // Summary Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _getResultGradientColors(result),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getResultIcon(result),
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.videoName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${result.finalLabel} • ${result.confidenceScore.toStringAsFixed(1)}% Confidence',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ResultsCard(result: result),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getResultGradientColors(AnalysisResult result) {
    if (result.finalLabel.contains('FAKE')) {
      if (result.confidenceScore > 70) {
        return [Colors.red.shade800, Colors.black];
      } else {
        return [Colors.orange.shade800, Colors.black];
      }
    } else {
      if (result.confidenceScore > 80) {
        return [Colors.green.shade800, Colors.black];
      } else {
        return [Colors.blue.shade800, Colors.black];
      }
    }
  }

  IconData _getResultIcon(AnalysisResult result) {
    if (result.finalLabel.contains('FAKE')) {
      return Icons.warning;
    } else {
      return Icons.verified;
    }
  }
}