import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/customer/parking/bookparking.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import '../../config/authconfig.dart';
import '../../config/colorcode.dart';
import 'drawer/Searchscreen.dart';
import 'drawer/mylist.dart';
import 'drawer/transaction.dart';

class ChatScreen extends StatefulWidget {
  final String userid;
  const ChatScreen({super.key, required this.userid});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Widget> messages = [];
  bool isLoading = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  // Payment dispute pending data
  String? _pendingPaymentDisputeType;
  String? _pendingPaymentDisputeImage;
  String? _pendingPaymentDisputeDescription;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Load chat history from backend
  Future<void> _loadChatHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}chatbox/history/${widget.userid}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data']['messages'] != null) {
          final List<dynamic> savedMessages = data['data']['messages'];
          
          setState(() {
            messages.clear();
            
            // Load saved messages
            for (var msg in savedMessages) {
              if (msg['messageType'] == 'user') {
                messages.add(UserMessage(
                  text: msg['message'] ?? '',
                  time: msg['time'] ?? DateFormat('hh:mm a').format(DateTime.now()),
                  imageUrl: msg['image'],
                ));
              } else if (msg['messageType'] == 'admin') {
                // Admin messages appear on the left
                messages.add(AdminMessage(
                  text: msg['message'] ?? '',
                  time: msg['time'] ?? DateFormat('hh:mm a').format(DateTime.now()),
                  imageUrl: msg['image'],
                ));
              } else {
                // For bot messages, we need to reconstruct them
                // Since we don't store options in backend, we'll just show text
                messages.add(BotMessage(
                  text: msg['message'] ?? '',
                  time: msg['time'] ?? DateFormat('hh:mm a').format(DateTime.now()),
                ));
              }
            }
            
            // If no messages, show greeting
            if (messages.isEmpty) {
              _showGreetingAndMainMenu();
            }
          });
          
          _scrollToBottom();
        } else {
          // No history, show greeting
          _showGreetingAndMainMenu();
        }
      } else {
        // Error loading, show greeting
        _showGreetingAndMainMenu();
      }
    } catch (e) {
      print('Error loading chat history: $e');
      // On error, show greeting
      _showGreetingAndMainMenu();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Save message to backend
  Future<void> _saveMessageToBackend(String text, {String? imagePath, String messageType = 'user'}) async {
    try {
      final Map<String, dynamic> body = {
        'message': text,
        'messageType': messageType,
      };

      http.MultipartRequest? request;
      
      if (imagePath != null) {
        // Upload image with message
        request = http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}chatbox/message/${widget.userid}'),
        );
        
        final file = File(imagePath);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('image', imagePath),
          );
        }
        
        request.fields['message'] = text;
        request.fields['messageType'] = messageType;
      } else {
        // Text only message
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}chatbox/message/${widget.userid}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        
        if (response.statusCode != 200) {
          print('Error saving message: ${response.body}');
        }
      }

      if (request != null) {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode != 200) {
          print('Error saving message with image: ${response.body}');
        }
      }
    } catch (e) {
      print('Error saving message to backend: $e');
      // Don't show error to user, message is already displayed
    }
  }

  void _handleUserMessage(String text, {String? imagePath}) {
    setState(() {
      messages.add(UserMessage(
        text: text,
        time: DateFormat('hh:mm a').format(DateTime.now()),
        imagePath: imagePath,
        imageUrl: null, // Will be set after upload
      ));
    });
    _messageController.clear();
    _scrollToBottom();
    
    // Save to backend
    _saveMessageToBackend(text, imagePath: imagePath);
  }

  void _sendCustomMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      // Check if there's a pending payment dispute
      if (_pendingPaymentDisputeType != null) {
        // Store description and create dispute ticket
        _pendingPaymentDisputeDescription = text;
        _handleUserMessage(text);
        _createPaymentDisputeWithData();
      } else {
        _handleUserMessage(text);
      }
    }
  }

  Future<void> _createPaymentDisputeWithData() async {
    if (_pendingPaymentDisputeType == null) return;

    try {
      setState(() {
        isLoading = true;
      });

      // Create multipart request for screenshot upload
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}payment-dispute'),
      );

      // Add screenshot file if available
      if (_pendingPaymentDisputeImage != null) {
        final file = File(_pendingPaymentDisputeImage!);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('screenshot', _pendingPaymentDisputeImage!),
          );
        }
      }

      // Add form fields
      request.fields['userId'] = widget.userid;
      request.fields['issueType'] = _pendingPaymentDisputeType!;
      request.fields['description'] = _pendingPaymentDisputeDescription ?? 'Payment dispute raised from chat support';

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final ticketId = data['data']['ticketId'];

          // Show success message with ticket ID
          setState(() {
            messages.add(BotMessage(
              text: "Payment dispute ticket created successfully! Your ticket ID is: $ticketId. Our admin team will review and respond soon.",
              time: DateFormat('hh:mm a').format(DateTime.now()),
            ));
          });

          // Show ticket ID in chat
          _handleUserMessage('Ticket ID: $ticketId');

          _scrollToBottom();
          _saveMessageToBackend("Payment dispute ticket created! Ticket ID: $ticketId", messageType: 'bot');

          // Clear pending dispute data
          _pendingPaymentDisputeType = null;
          _pendingPaymentDisputeImage = null;
          _pendingPaymentDisputeDescription = null;
        } else {
          throw Exception(data['message'] ?? 'Failed to create ticket');
        }
      } else {
        throw Exception('Failed to create payment dispute ticket: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating payment dispute ticket: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        // Check if there's a pending payment dispute
        if (_pendingPaymentDisputeType != null) {
          // Store image and create dispute ticket
          _pendingPaymentDisputeImage = image.path;
          _handleUserMessage('Screenshot uploaded', imagePath: image.path);
          
          // If user has typed description, create ticket immediately
          if (_pendingPaymentDisputeDescription != null) {
            _createPaymentDisputeWithData();
          } else {
            // Show message asking for description
            setState(() {
              messages.add(BotMessage(
                text: "Screenshot uploaded! Please describe your issue or we'll create the ticket with the screenshot.",
                time: DateFormat('hh:mm a').format(DateTime.now()),
              ));
            });
            _scrollToBottom();
            _saveMessageToBackend("Screenshot uploaded! Please describe your issue or we'll create the ticket with the screenshot.", messageType: 'bot');
            
            // Auto-create ticket after a short delay if no description
            Future.delayed(const Duration(seconds: 3), () {
              if (_pendingPaymentDisputeType != null && _pendingPaymentDisputeImage != null && _pendingPaymentDisputeDescription == null) {
                _createPaymentDisputeWithData();
              }
            });
          }
        } else {
          // Regular image message
          _handleUserMessage('Image', imagePath: image.path);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showGreetingAndMainMenu() {
    setState(() {
      messages.add(BotMessage(
        text: "Hello! Welcome to ParkMyWheels. How can I assist you today?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const [
          "Find a Parking Spot",
          "Book a Parking Space",
          "Manage My Booking",
          "Payment & Billing",
          "Support & Assistance"
        ],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          _handleMainMenuOption(option);
        },
      ));
    });
    _scrollToBottom();
  }

  void _handleMainMenuOption(String option) {
    switch (option) {
      case "Find a Parking Spot":
        _redirectToPage("Explore Page");
        break;
      case "Book a Parking Space":
        _redirectToPage("Booking Page");
        break;
      case "Manage My Booking":
        _showManageBookingOptions();
        break;
      case "Payment & Billing":
        _showPaymentAndBillingOptions();
        break;
      case "Support & Assistance":
        _showSupportAndAssistanceOptions();
        break;
      default:
        _showThankYouMessage();
    }
  }

  void _redirectToPage(String pageName) {
    setState(() {
      messages.add(BotMessage(
        text: "Redirecting to $pageName.",
        time: DateFormat('hh:mm a').format(DateTime.now()),
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("Redirecting to $pageName.", messageType: 'bot');
    
    // Navigate after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      switch (pageName) {
        case "Explore Page":
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchScreen(
                userid: widget.userid,
                title: "Explore Parking Space(s)",
              ),
            ),
          );
          break;
        case "Booking Page":
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChooseParkingPage(
                userId: widget.userid,
                selectedOption: 'Instant',
              ),
            ),
          );
          break;
        case "My Bookings Page":
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParkingPage(userId: widget.userid),
            ),
          );
          break;
        case "Edit Bookings Page":
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParkingPage(userId: widget.userid),
            ),
          );
          break;
        case "Transaction Page":
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Transactionhistory(userId: widget.userid),
            ),
          );
          break;
        case "Help and Support Page":
          // Don't redirect, just show message
          setState(() {
            messages.add(BotMessage(
              text: "Please describe your issue or share a screenshot, and we'll create a support ticket for you.",
              time: DateFormat('hh:mm a').format(DateTime.now()),
            ));
          });
          _scrollToBottom();
          _saveMessageToBackend("Please describe your issue or share a screenshot, and we'll create a support ticket for you.", messageType: 'bot');
          break;
        default:
          break;
      }
    });
  }

  void _showManageBookingOptions() {
    setState(() {
      messages.add(BotMessage(
        text: "What would you like to do?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const [
          "View My Booking",
          "Extend Parking Time",
          "Cancel Booking",
          "Reschedule Booking"
        ],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          _handleManageBookingOption(option);
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("What would you like to do?", messageType: 'bot');
  }

  void _handleManageBookingOption(String option) {
    switch (option) {
      case "View My Booking":
        _redirectToPage("My Bookings Page");
        break;
      case "Extend Parking Time":
        _showExtendParkingOptions();
        break;
      case "Cancel Booking":
        _showCancelBookingOptions();
        break;
      case "Reschedule Booking":
        _showRescheduleBookingOptions();
        break;
      default:
        _showThankYouMessage();
    }
  }

  void _showExtendParkingOptions() {
    setState(() {
      messages.add(BotMessage(
        text: "Extension allowed for 3hrs only. Do you agree?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const ["Agree", "Disagree"],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          if (option == "Agree") {
            _redirectToPage("My Bookings Page");
          } else {
            _showThankYouMessage();
          }
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("Extension allowed for 3hrs only. Do you agree?", messageType: 'bot');
  }

  void _showCancelBookingOptions() {
    setState(() {
      messages.add(BotMessage(
        text: "For cancellations, please note: Refunds are only available if canceled 3 hours before start time. Do you agree?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const ["Agree", "Disagree"],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          if (option == "Agree") {
            _redirectToPage("Edit Bookings Page");
          } else {
            _showThankYouMessage();
          }
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("For cancellations, please note: Refunds are only available if canceled 3 hours before start time. Do you agree?", messageType: 'bot');
  }

  void _showRescheduleBookingOptions() {
    setState(() {
      messages.add(BotMessage(
        text: "Reschedule for same day or different day?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const ["Same Day", "Different Day"],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          if (option == "Same Day") {
            _showSameDayRescheduleOptions();
          } else {
            _redirectToPage("Edit Bookings Page");
          }
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("Reschedule for same day or different day?", messageType: 'bot');
  }

  void _showSameDayRescheduleOptions() {
    setState(() {
      messages.add(BotMessage(
        text: "Rescheduling allowed only within 3hrs window. Do you agree?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const ["Agree", "Disagree"],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          if (option == "Agree") {
            _redirectToPage("Edit Bookings Page");
          } else {
            _showThankYouMessage();
          }
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("Rescheduling allowed only within 3hrs window. Do you agree?", messageType: 'bot');
  }

  void _showPaymentAndBillingOptions() {
    setState(() {
      messages.add(BotMessage(
        text: "How can I assist you with payments?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const ["View Payment History", "Report a Payment Issue"],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          _handlePaymentAndBillingOption(option);
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("How can I assist you with payments?", messageType: 'bot');
  }

  void _handlePaymentAndBillingOption(String option) {
    switch (option) {
      case "View Payment History":
        _redirectToPage("Transaction Page");
        break;
      case "Report a Payment Issue":
        _showPaymentIssueOptions();
        break;
      default:
        _showThankYouMessage();
    }
  }

  void _showPaymentIssueOptions() {
    setState(() {
      messages.add(BotMessage(
        text: "If you have a payment issue, please describe the problem:",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const ["Incorrect charge", "Refund not received"],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          _handleSpecificPaymentIssue(option);
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("If you have a payment issue, please describe the problem:", messageType: 'bot');
  }

  void _handleSpecificPaymentIssue(String option) {
    switch (option) {
      case "Incorrect charge":
      case "Refund not received":
        _showPaymentIssueDetails(option);
        break;
      default:
        _showThankYouMessage();
    }
  }

  void _showPaymentIssueDetails(String issue) {
    setState(() {
      messages.add(BotMessage(
        text: "Payment related queries:",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const [
          "Payment made but booking not confirmed",
          "Booking is getting struck at payment page"
        ],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          _handlePaymentIssueDetail(option);
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("Payment related queries:", messageType: 'bot');
  }

  void _handlePaymentIssueDetail(String option) {
    switch (option) {
      case "Payment made but booking not confirmed":
        _showPaymentDisputePrompt(option);
        break;
      case "Booking is getting struck at payment page":
        _showPaymentDisputePrompt(option);
        break;
      default:
        _showThankYouMessage();
    }
  }

  void _showPaymentDisputePrompt(String issueType) {
    // Store the pending payment dispute type
    _pendingPaymentDisputeType = issueType;
    
    setState(() {
      messages.add(BotMessage(
        text: issueType == "Payment made but booking not confirmed"
            ? "Please provide the payment screenshot or describe your issue. You can share an image or type a message."
            : "Please provide the screenshot of error or describe your issue. You can share an image or type a message.",
        time: DateFormat('hh:mm a').format(DateTime.now()),
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend(
      issueType == "Payment made but booking not confirmed"
          ? "Please provide the payment screenshot or describe your issue. You can share an image or type a message."
          : "Please provide the screenshot of error or describe your issue. You can share an image or type a message.",
      messageType: 'bot',
    );
  }

  Future<void> _pickScreenshotForDispute() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        _pendingPaymentDisputeImage = image.path;
        // Show uploaded image in chat
        _handleUserMessage('Screenshot uploaded', imagePath: image.path);
        
        // If user has typed description, create ticket immediately
        if (_pendingPaymentDisputeDescription != null) {
          _createPaymentDisputeWithData();
        } else {
          // Show message asking for description
          setState(() {
            messages.add(BotMessage(
              text: "Screenshot uploaded! Please describe your issue or we'll create the ticket with the screenshot.",
              time: DateFormat('hh:mm a').format(DateTime.now()),
            ));
          });
          _scrollToBottom();
          _saveMessageToBackend("Screenshot uploaded! Please describe your issue or we'll create the ticket with the screenshot.", messageType: 'bot');
          
          // Auto-create ticket after a short delay if no description is provided
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _pendingPaymentDisputeType != null && _pendingPaymentDisputeImage != null && _pendingPaymentDisputeDescription == null) {
              _createPaymentDisputeWithData();
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking screenshot: $e')),
      );
    }
  }


  void _showSupportAndAssistanceOptions() {
    setState(() {
      messages.add(BotMessage(
        text: "What do you need help with?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const [
          "Report an Occupied Spot",
          "Parking Lot Entry Issue",
          "Speak to a Support Agent"
        ],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          _handleSupportAndAssistanceOption(option);
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("What do you need help with?", messageType: 'bot');
  }

  void _handleSupportAndAssistanceOption(String option) {
    switch (option) {
      case "Report an Occupied Spot":
      case "Parking Lot Entry Issue":
        _raiseSupportTicket(option);
        break;
      case "Speak to a Support Agent":
        _connectToSupportAgent();
        break;
      default:
        _showThankYouMessage();
    }
  }

  void _raiseSupportTicket(String issue) {
    setState(() {
      messages.add(BotMessage(
        text: "Apologies for the inconvenience caused, shall I raise a ticket for this incident?",
        time: DateFormat('hh:mm a').format(DateTime.now()),
        options: const ["Yes", "No"],
        onOptionSelected: (option) {
          _handleUserMessage(option);
          _saveMessageToBackend(option, messageType: 'user');
          if (option == "Yes") {
            // Set pending dispute type based on the issue
            _pendingPaymentDisputeType = issue;
            _showPaymentDisputePrompt(issue);
          } else {
            _showThankYouMessage();
          }
        },
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("Apologies for the inconvenience caused, shall I raise a ticket for this incident?", messageType: 'bot');
  }

  void _connectToSupportAgent() {
    setState(() {
      messages.add(BotMessage(
        text: "Connecting you to a live agent...",
        time: DateFormat('hh:mm a').format(DateTime.now()),
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("Connecting you to a live agent...", messageType: 'bot');
  }

  void _showThankYouMessage() {
    setState(() {
      messages.add(BotMessage(
        text: "Thanks, have a nice day!",
        time: DateFormat('hh:mm a').format(DateTime.now()),
      ));
    });
    _scrollToBottom();
    _saveMessageToBackend("Thanks, have a nice day!", messageType: 'bot');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Support Screen',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'We typically reply in about 7 minutes',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w200,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                _buildDateHeader(),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: messages,
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
      ), );
  }

  Widget _buildDateHeader() {
    String currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[200],
      child: Center(
        child: Text(
          currentDate,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.image, color: ColorUtils.primarycolor()),
              onPressed: _pendingPaymentDisputeType != null ? _pickScreenshotForDispute : _pickImage,
              tooltip: _pendingPaymentDisputeType != null ? 'Pick Screenshot' : 'Pick Image',
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: _pendingPaymentDisputeType != null 
                      ? 'Describe your payment issue or share screenshot...'
                      : 'Type a message...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide(color: ColorUtils.primarycolor()),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendCustomMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: ColorUtils.primarycolor(),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendCustomMessage,
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserMessage extends StatelessWidget {
  final String text;
  final String time;
  final String? imagePath;
  final String? imageUrl;

  const UserMessage({
    super.key,
    required this.text,
    required this.time,
    this.imagePath,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorUtils.primarycolor(),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(imagePath!),
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.error, color: Colors.white);
                        },
                      ),
                    ),
                  if ((imagePath != null || imageUrl != null) && text != 'Image')
                    const SizedBox(height: 8),
                  if (text != 'Image' || (imagePath == null && imageUrl == null))
                    Text(
                      text,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                time,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminMessage extends StatelessWidget {
  final String text;
  final String time;
  final String? imageUrl;

  const AdminMessage({
    super.key,
    required this.text,
    required this.time,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(
                        color: Colors.blue[200]!,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error, color: Colors.blue);
                              },
                            ),
                          ),
                        if (imageUrl != null && text != 'Image')
                          const SizedBox(height: 8),
                        if (text != 'Image' || imageUrl == null)
                          Text(
                            text,
                            style: GoogleFonts.poppins(
                              color: Colors.blue[900],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 28),
              child: Text(
                time,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BotMessage extends StatelessWidget {
  final String text;
  final String time;
  final List<String>? options;
  final Function(String)? onOptionSelected;

  const BotMessage({
    super.key,
    required this.text,
    required this.time,
    this.options,
    this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            if (options != null && options!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                    )
                  ],
                ),
                child: Column(
                  children: options!
                      .map((option) => Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onOptionSelected?.call(option),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: option == options!.last
                                        ? BorderSide.none
                                        : BorderSide(
                                            color: Colors.grey[200]!,
                                          ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[800],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                time,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
