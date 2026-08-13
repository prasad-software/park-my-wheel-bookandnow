import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class UpiPaymentQrPage extends StatelessWidget {
  final String title;
  final String upiUri;
  final String? amount;
  final String? vendorName;

  const UpiPaymentQrPage({
    super.key,
    required this.title,
    required this.upiUri,
    this.amount,
    this.vendorName,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmt = (amount ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: ColorUtils.primarycolor(),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if ((vendorName ?? '').trim().isNotEmpty) ...[
                Text(
                  vendorName!.trim(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (displayAmt.isNotEmpty && displayAmt != '0') ...[
                Text(
                  'Amount: ₹$displayAmt',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 16),
              ],
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: PrettyQrView.data(
                      data: upiUri,
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
              ),
              const SizedBox(height: 16),
              Text(
                'Scan to pay via UPI',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primarycolor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

