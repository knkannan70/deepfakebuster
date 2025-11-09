import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About Deepfake Buster',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Header Section
            _buildAppHeader(),
            SizedBox(height: 30),

            // About App Section
            _buildSectionTitle('About The App'),
            SizedBox(height: 15),
            _buildInfoCard(
              'Deepfake Buster is an advanced AI-powered mobile application designed to detect face-swap deepfake videos with exceptional accuracy. Our system employs two specialized AI models working in parallel to provide comprehensive analysis and reliable results.',
            ),

            SizedBox(height: 25),

            // Key Features
            _buildSectionTitle('Key Features'),
            SizedBox(height: 15),
            _buildFeatureGrid(),

            SizedBox(height: 25),

            // AI Models Section
            _buildSectionTitle('Advanced AI Technology'),
            SizedBox(height: 15),
            _buildModelCards(),

            SizedBox(height: 25),

            // How It Works
            _buildSectionTitle('How It Works'),
            SizedBox(height: 15),
            _buildProcessSteps(),

            SizedBox(height: 25),

            // Developer Information
            _buildSectionTitle('Developer Information'),
            SizedBox(height: 15),
            _buildOwnerCard(context),

            SizedBox(height: 25),

            // Technology Stack
            _buildTechStack(),

            SizedBox(height: 30),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red.shade900, Colors.black],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.security, size: 40, color: Colors.red),
          ),
          SizedBox(height: 20),
          Text(
            'Deepfake Buster',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Version 2.0.0',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade300),
          ),
          SizedBox(height: 10),
          Text(
            'Advanced Deepfake Detection',
            style: TextStyle(
              fontSize: 14,
              color: Colors.red.shade300,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          text,
          style: TextStyle(fontSize: 16, height: 1.6, color: Colors.white70),
          textAlign: TextAlign.justify,
        ),
      ),
    );
  }

  Widget _buildFeatureGrid() {
    List<Map<String, dynamic>> features = [
      {
        'icon': Icons.video_library,
        'title': 'Video Analysis',
        'desc': 'Upload and preview videos',
      },
      {
        'icon': Icons.analytics,
        'title': 'Multi-Model AI',
        'desc': 'Two parallel AI models',
      },
      {
        'icon': Icons.score,
        'title': 'Confidence Scores',
        'desc': 'Detailed accuracy metrics',
      },
      {
        'icon': Icons.history,
        'title': 'Analysis History',
        'desc': 'Track previous scans',
      },
      {
        'icon': Icons.speed,
        'title': 'Real-time Processing',
        'desc': 'Fast and efficient',
      },
      {
        'icon': Icons.security,
        'title': 'Secure & Private',
        'desc': 'Your data stays local',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.1,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          padding: EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(features[index]['icon'], color: Colors.red, size: 30),
              SizedBox(height: 10),
              Text(
                features[index]['title'],
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 5),
              Text(
                features[index]['desc'],
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModelCards() {
    List<Map<String, String>> models = [
      {
        'title': 'Facial Artifact Detection',
        'description':
            'Detects visual inconsistencies and artifacts in facial regions',
        'accuracy': '98% Accuracy',
      },
      {
        'title': 'Temporal Consistency',
        'description':
            'Analyzes frame-to-frame consistency and natural movement patterns',
        'accuracy': '96% Accuracy',
      },
      {
        'title': 'Deep Learning Ensemble',
        'description':
            'Advanced neural network combining multiple detection methodologies',
        'accuracy': '99% Accuracy',
      },
    ];

    return Column(
      children:
          models.map((model) {
            return Container(
              margin: EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.grey.shade900, Colors.black],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade800),
              ),
              padding: EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red, Colors.orange],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model['title']!,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          model['description']!,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            model['accuracy']!,
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildProcessSteps() {
    List<Map<String, String>> steps = [
      {
        'step': '1',
        'title': 'Upload Video',
        'desc': 'Select video from gallery',
      },
      {
        'step': '2',
        'title': 'AI Analysis',
        'desc': 'Two models process in parallel',
      },
      {
        'step': '3',
        'title': 'Generate Report',
        'desc': 'Comprehensive results with scores',
      },
      {
        'step': '4',
        'title': 'View Details',
        'desc': 'Frame-by-frame analysis available',
      },
    ];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children:
            steps.map((step) {
              return Container(
                margin: EdgeInsets.only(bottom: 15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          step['step']!,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['title']!,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            step['desc']!,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildOwnerCard(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Profile Section
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red.shade800, Colors.black],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade800,
                    backgroundImage: AssetImage(
                      'assets/images/owner_photo.jpeg',
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Kannan M',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Flutter Developer & AI Specialis',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade300,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: Colors.red, size: 16),
                      SizedBox(width: 5),
                      Text(
                        'Tirunelvelli, India',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // About Section
            Text(
              'About the Developer',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Passionate Flutter developer with 3+ years of experience in building cross-platform mobile applications. Specialized in AI-integrated apps, clean architecture, and creating user-friendly interfaces. Committed to developing innovative solutions that address real-world challenges in digital security and media authenticity.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white70,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            // Contact Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchPortfolioURL(context),
                    icon: Icon(Icons.public, color: Colors.white, size: 20),
                    label: Text(
                      'Portfolio',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchEmail(context),
                    icon: Icon(Icons.email, color: Colors.white, size: 20),
                    label: Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),

            // Social Links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(
                  icon: Icons.code,
                  onTap: () => _launchURL('https://github.com/KannanM'),
                  color: Colors.grey.shade800,
                ),
                SizedBox(width: 10),
                _buildSocialButton(
                  icon: Icons.work,
                  onTap: () => _launchURL('https://linkedin.com/in/kannanm'),
                  color: Colors.blue.shade800,
                ),
                SizedBox(width: 10),
                _buildSocialButton(
                  icon: Icons.article,
                  onTap: () => _launchURL('https://medium.com/@kannanm'),
                  color: Colors.green.shade800,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildTechStack() {
    List<String> technologies = [
      'Flutter',
      'Dart',
      'TensorFlow Lite',
      'Python',
      'Firebase',
      'REST API',
      'Git',
      'Docker',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Technology Stack'),
        SizedBox(height: 15),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
              technologies.map((tech) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Text(
                    tech,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Deepfake Buster',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Protecting Digital Integrity Through Advanced AI',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 15),
          Divider(color: Colors.grey.shade700),
          SizedBox(height: 10),
          Text(
            'Developed with ❤️ by Kannan M',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          SizedBox(height: 5),
          Text(
            '© 2025 Kannan M Deepfake Buster. All rights reserved.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Fixed URL Launch Functions
  Future<void> _launchPortfolioURL(BuildContext context) async {
    const String url = 'https://portfolio-roan-alpha-36.vercel.app/';
    await _launchURL(url);
  }

  Future<void> _launchEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'knkannan70@gmail.com',
      query: Uri.encodeFull(
        'subject=Deepfake Buster App Inquiry&body=Hello Kannan, I would like to know more about your Deepfake Buster application.',
      ),
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      _showErrorDialog(
        context,
        'Could not launch email client. Please make sure you have an email app installed.',
      );
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 10),
              Text('Error', style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(message),
          backgroundColor: Colors.grey.shade900,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          contentTextStyle: TextStyle(color: Colors.white),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
