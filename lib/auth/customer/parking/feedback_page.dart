import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/config/authconfig.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/config/colorcode.dart';

class FeedbackPage extends StatefulWidget {
  final String userId;
  final String vendorId;
  final String vendorName;
  final String? bookingId;

  const FeedbackPage({
    super.key,
    required this.userId,
    required this.vendorId,
    required this.vendorName,
    this.bookingId,
  });

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> with TickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _remarksController = TextEditingController();
  final List<String> _feedbackPoints = [
    'Clean parking area',
    'Easy to find location',
    'Good security',
    'Affordable pricing',
    'Friendly staff',
    'Well maintained',
    'Quick entry/exit',
    'Good lighting',
  ];
  final Set<String> _selectedPoints = {};
  bool _isSubmitting = false;
  late AnimationController _starAnimController;
  late AnimationController _slideAnimController;

  @override
  void initState() {
    super.initState();
    _feedbackPoints.shuffle(); // Shuffle the feedback points
    _starAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimController.forward();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _starAnimController.dispose();
    _slideAnimController.dispose();
    super.dispose();
  }

  Future<bool> _submitFeedback() async {
    if (_rating == 0) {
      Fluttertoast.showToast(
        msg: "Please provide a rating",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.orange,
      );
      return false;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String description = '';
      if (_selectedPoints.isNotEmpty) {
        description = _selectedPoints.join(', ');
      }
      if (_remarksController.text.trim().isNotEmpty) {
        if (description.isNotEmpty) {
          description += '\n\n';
        }
        description += _remarksController.text.trim();
      }

      final feedbackPointsList = _selectedPoints.toList();
      String apiUrl = "${ApiConfig.baseUrl}updatefeedback/${widget.userId}";

      // Debug logging
      print('📝 Submitting feedback:');
      print('  - UserId: ${widget.userId}');
      print('  - VendorId: ${widget.vendorId}');
      print('  - BookingId: ${widget.bookingId ?? "NOT PROVIDED"}');
      print('  - Rating: $_rating');
      print('  - API URL: $apiUrl');

      final requestBody = {
        'userId': widget.userId,
        'vendorId': widget.vendorId,
        'bookingId': widget.bookingId ?? '',
        'rating': _rating.toDouble(),
        'description': description.isEmpty ? 'No additional comments' : description,
        'feedbackPoints': feedbackPointsList,
      };

      print('  - Request Body: ${jsonEncode(requestBody)}');

      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Fluttertoast.showToast(
          msg: "Thank you for your feedback!",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: const Color(0xFF3BA775),
        );
        return true;
      } else {
        // Parse error response
        try {
          final errorData = json.decode(response.body);
          final errorMessage = errorData['message'] ?? 'Failed to submit feedback';
          print('❌ Error: $errorMessage');
          Fluttertoast.showToast(
            msg: errorMessage,
            toastLength: Toast.LENGTH_LONG,
            backgroundColor: Colors.red,
          );
        } catch (e) {
          Fluttertoast.showToast(
            msg: "Failed to submit feedback: ${response.statusCode}",
            toastLength: Toast.LENGTH_SHORT,
            backgroundColor: Colors.red,
          );
        }
        return false;
      }
    } catch (e) {
      print("❌ Error submitting feedback: $e");
      Fluttertoast.showToast(
        msg: "Error submitting feedback: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
      );
      return false;
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _skipFeedback() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ParkingPage(userId: widget.userId),
      ),
    );
  }

  void _handleSubmit() async {
    final success = await _submitFeedback();
    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ParkingPage(userId: widget.userId),
        ),
      );
    }
  }

  Color _getRatingColor() {
    if (_rating == 0) return Colors.grey;
    if (_rating <= 2) return Colors.orange;
    if (_rating <= 3) return Colors.amber;
    if (_rating <= 4) return const Color(0xFF3BA775);
    return const Color(0xFF2E8B57);
  }

  String _getRatingEmoji() {
    if (_rating == 0) return '🤔';
    if (_rating == 1) return '😞';
    if (_rating == 2) return '😐';
    if (_rating == 3) return '🙂';
    if (_rating == 4) return '😊';
    return '🤩';
  }

  String _getRatingText() {
    if (_rating == 0) return 'Tap to rate';
    if (_rating == 1) return 'Poor';
    if (_rating == 2) return 'Fair';
    if (_rating == 3) return 'Good';
    if (_rating == 4) return 'Very Good';
    return 'Excellent';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF3BA775).withOpacity(0.05),
              Colors.white,
              const Color(0xFF3BA775).withOpacity(0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black87),
                        onPressed: _skipFeedback,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Feedback',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _slideAnimController,
                      curve: Curves.easeOut,
                    )),
                    child: FadeTransition(
                      opacity: _slideAnimController,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Hero Section
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3BA775).withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Icon
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF3BA775),
                                        const Color(0xFF2E8B57),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3BA775).withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.feedback_outlined,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'How was your experience?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.vendorName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3BA775),
                                    height: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                // Star Rating with Emoji
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _rating = index + 1;
                                        });
                                        _starAnimController.forward(from: 0);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeInOut,
                                          child: Icon(
                                            index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                            size: 42,
                                            color: index < _rating
                                                ? _getRatingColor()
                                                : Colors.grey[300],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 16),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Container(
                                    key: ValueKey(_rating),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _getRatingColor().withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _getRatingEmoji(),
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _getRatingText(),
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: _getRatingColor(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Feedback Points Section
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3BA775).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.thumb_up_outlined,
                                    color: Color(0xFF3BA775),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'What did you like?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _feedbackPoints.map((point) {
                              final isSelected = _selectedPoints.contains(point);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedPoints.remove(point);
                                    } else {
                                      _selectedPoints.add(point);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: (MediaQuery.of(context).size.width - 64) / 3,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                      colors: [
                                        const Color(0xFF3BA775),
                                        const Color(0xFF2E8B57),
                                      ],
                                    )
                                        : null,
                                    color: isSelected ? null : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                      BoxShadow(
                                        color: const Color(0xFF3BA775).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                        : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.circle_outlined,
                                          key: ValueKey(isSelected),
                                          color: isSelected ? Colors.white : Colors.grey[400],
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        point,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                          // Remarks Section
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3BA775).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.edit_note,
                                    color: Color(0xFF3BA775),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Additional Remarks',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _remarksController,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: 'Share your thoughts with us...',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(20),
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Submit Button
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _rating > 0
                                  ? [
                                BoxShadow(
                                  color: const Color(0xFF3BA775).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                                  : [],
                            ),
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _rating > 0
                                    ? const Color(0xFF3BA775)
                                    :  ColorUtils
                                    .primarycolor(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Submit Feedback',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Skip Button
                          TextButton(
                            onPressed: _isSubmitting ? null : _skipFeedback,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Skip for now',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),),
    );
  }
}