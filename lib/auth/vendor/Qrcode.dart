import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide MemoryImage;
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pdf/pdf.dart'; // 👈 Required for PdfPageFormat

class QRPage extends StatefulWidget {
  final String vendorid;
  final String vendorname;

  const QRPage({super.key, required this.vendorid, required this.vendorname});

  @override
  State<QRPage> createState() => _QRPageState();
}

class _QRPageState extends State<QRPage> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isLoading = false;
  final bool _isPermissionDenied = false;

  File? _savedPdfFile;

  String get _qrData => 'vendorName:${widget.vendorname}\nvendorId:${widget.vendorid}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "View QR",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ColorUtils.primarycolor(),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
          children: [
            Card(
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: RepaintBoundary(
                  key: _globalKey,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: PrettyQrView.data(
                            data: _qrData,
                            errorCorrectLevel: QrErrorCorrectLevel.H,
                            decoration: PrettyQrDecoration(
                              shape: PrettyQrSmoothSymbol(
                                color: ColorUtils.primarycolor(),
                              ),
                              background: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Scan this QR code to Book Now',
              style: GoogleFonts.poppins(
                textStyle: theme.textTheme.titleMedium,
              ),
            ),
            if (_isPermissionDenied)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Storage permission required to save QR code',
                  style: GoogleFonts.poppins(
                    textStyle: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: Text(
                    'Save to PDF',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: ColorUtils.primarycolor(),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 4,
                  ),
                  onPressed: _isLoading ? null : _downloadQrAsPdf,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: Text(
                    'Share as PDF',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: ColorUtils.primarycolor(),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 4,
                  ),
                  onPressed: _isLoading ? null : _shareQrImage,
                ),
              ],
            ),
            if (_savedPdfFile != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  'View Saved PDF',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () async {
                  // await OpenFile.open(_savedPdfFile!.path, type: 'application/pdf');
                },
              ),
            ]
          ],
        ),
      ),
      ),  );
  }


  Future<void> _downloadQrAsPdf() async {
    setState(() => _isLoading = true);

    final imageBytes = await _capturePngBytes();
    if (imageBytes == null) {
      _showMessage('Error capturing image');
      setState(() => _isLoading = false);
      return;
    }

    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);





    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('Vendor Name: ${widget.vendorname}', style: const pw.TextStyle(fontSize: 16)),
                pw.Image(image, width: 200, height: 200),
                pw.SizedBox(height: 8),
                pw.Text('Scan this QR code to Book Now', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Powered by ParkMyWheels', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _shareQrImage() async {
    setState(() => _isLoading = true);

    final imageBytes = await _capturePngBytes();
    if (imageBytes == null) {
      _showMessage('Error generating image');
      setState(() => _isLoading = false);
      return;
    }

    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text('Vendor Name: ${widget.vendorname}', style: const pw.TextStyle(fontSize: 16)),
                pw.Image(image, width: 200, height: 200),
                pw.SizedBox(height: 8),
                pw.Text('Scan this QR code to Book Now', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Powered by ParkMyWheels', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/QR_${widget.vendorname}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'Vendor QR: ${widget.vendorname}');
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      _showMessage('Failed to share PDF');
    }

    setState(() => _isLoading = false);
  }

  Future<Uint8List?> _capturePngBytes() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.5);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing QR image: $e');
      return null;
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
