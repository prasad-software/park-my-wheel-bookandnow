import 'package:flutter/material.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'dart:io';

void main() {
  runApp(const PrinterTestApp());
}

class PrinterTestApp extends StatelessWidget {
  const PrinterTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sumi Printer Test',
      home: const PrinterTestScreen(),
    );
  }
}

class PrinterTestScreen extends StatefulWidget {
  const PrinterTestScreen({super.key});

  @override
  State<PrinterTestScreen> createState() => _PrinterTestScreenState();
}

class _PrinterTestScreenState extends State<PrinterTestScreen> {
  String _status = 'Checking Sumi printer...';
  List<String> _logs = [];
  bool _isSumiReady = false;

  void _addLog(String log) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $log');
      if (_logs.length > 30) _logs.removeAt(0);
    });
    print(log);
  }

  @override
  void initState() {
    super.initState();
    _checkSumiPrinter();
  }

  Future<void> _checkSumiPrinter() async {
    _addLog('=== Starting Sumi Printer Detection ===');
    setState(() => _status = 'Detecting Sumi...');
    
    // Check platform
    if (!Platform.isAndroid) {
      _addLog('ERROR: Not Android platform');
      setState(() => _status = 'Not Android');
      return;
    }
    _addLog('✓ Android platform detected');

    // Test Sumi printer
    _addLog('Testing Sumi printer binding...');
    try {
      bool? bound = await SunmiPrinter.bindingPrinter();
      _addLog('Sumi binding result: $bound');
      
      if (bound == true) {
        _addLog('✓ Sumi printer bound successfully');
        try {
          await SunmiPrinter.initPrinter();
          _addLog('✓ Sumi printer initialized successfully');
          setState(() {
            _status = 'Sumi Ready';
            _isSumiReady = true;
          });
        } catch (e) {
          _addLog('✗ Sumi init failed: $e');
          setState(() => _status = 'Sumi Init Error');
        }
      } else {
        _addLog('✗ Sumi printer binding failed');
        setState(() => _status = 'Sumi Not Available');
      }
    } catch (e) {
      _addLog('✗ Sumi test error: $e');
      setState(() => _status = 'Sumi Error');
    }

    _addLog('=== Sumi Printer Detection Complete ===');
  }

  Future<void> _testPrint() async {
    if (!_isSumiReady) {
      _addLog('ERROR: Sumi printer not ready');
      return;
    }

    _addLog('=== Starting Test Print ===');
    try {
      // Test basic printing
      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.setAlignment(1);
      await SunmiPrinter.bold();
      await SunmiPrinter.printText("SUMI PRINTER TEST");
      await SunmiPrinter.resetBold();
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('*********************');
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Test Receipt');
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Date: ${DateTime.now().toString().substring(0, 19)}');
      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.printText('Vehicle: TEST-1234');
      await SunmiPrinter.printText('Amount: ₹100.00');
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('*********************');
      await SunmiPrinter.lineWrap(3);
      
      _addLog('✓ Test print sent successfully');
      _showSuccessDialog();
    } catch (e) {
      _addLog('✗ Test print failed: $e');
      _showErrorDialog(e.toString());
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Test print sent successfully! Check your Sumi printer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text('Print failed: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sumi Printer Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSumiReady ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isSumiReady ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSumiReady ? Icons.check_circle : Icons.error,
                    color: _isSumiReady ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Status: $_status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isSumiReady ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Debug Logs:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black87,
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logs[index],
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.green,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _checkSumiPrinter,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Re-check Sumi'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _testPrint,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSumiReady ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Test Print'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _logs.clear());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear Logs'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
