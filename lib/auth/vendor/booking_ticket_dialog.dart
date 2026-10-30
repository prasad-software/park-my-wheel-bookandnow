import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';

class BookingTicketDialog {
  static String cleanAmount(String amount) {
    final v = double.tryParse(amount.toString().trim());
    if (v == null) return amount;
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
  }

  static IconData getVehicleIcon(String vehicleType) {
    final t = vehicleType.trim().toLowerCase();
    if (t.contains('bike') || t.contains('motorcycle') || t.contains('two_wheeler')) {
      return Icons.two_wheeler;
    } else if (t.contains('car')) {
      return Icons.directions_car;
    } else {
      return Icons.local_shipping;
    }
  }

  static String resolvePlanLabel(String? sts, String? bookingtype) {
    final snap = (sts ?? bookingtype ?? '').trim().toLowerCase();
    if (snap.contains('pass')) {
      return sts ?? 'Pass';
    } else if (snap.contains('weekly')) {
      return 'Weekly Subscription';
    } else if (snap.contains('15day')) {
      return '15 Days Subscription';
    } else if (snap.contains('monthly') || snap.contains('subscript')) {
      return 'Monthly Subscription';
    } else if (snap == '24hr' || snap == '24 hours') {
      return '24 Hours';
    } else if (snap == 'instant') {
      return 'Instant Parking';
    } else if (snap.isNotEmpty && snap != 'null') {
      return sts ?? 'Hourly Parking';
    }
    return 'Hourly Parking';
  }

  static Widget _buildTicketInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    double labelFontSize = 12,
    double valueFontSize = 12,
    EdgeInsetsGeometry? padding,
  }) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: labelFontSize,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: (isBold && labelFontSize > 12)
                  ? Colors.black87
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: valueFontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> show({
    required BuildContext context,
    required String vendorName,
    required String bookingId,
    String? invoiceId,
    required String vehicleType,
    required String vehicleNumber,
    required String parkingDate,
    required String parkingTime,
    required String amount,
    String personName = '',
    String mobileNumber = '',
    String? receiptSts,
    double appliedValetAmount = 0.0,
    bool instantParkingReceipt = false,
    List<String> vehicleImages = const [],
    String? vendorId,
    String? bookType,
    bool isPrintAndExit = false,
    String? exitDate,
    String? exitTime,
  }) async {
    final String displayId =
        (invoiceId != null && invoiceId.trim().isNotEmpty)
            ? invoiceId.trim()
            : bookingId;

    final String planLabel = resolvePlanLabel(receiptSts, null);

    final double baseAmt =
        double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    // On Print and Exit, the passed amount is already the final calculated total
    final double totalWithValet = isPrintAndExit
        ? baseAmt
        : (baseAmt + (appliedValetAmount > 0 ? appliedValetAmount : 0.0));
    final String cleanedTotalAmt = cleanAmount(
      totalWithValet > 0 ? totalWithValet.toString() : amount,
    );
    final String displayAmount =
        (cleanedTotalAmt.isNotEmpty && cleanedTotalAmt != '0')
            ? '₹$cleanedTotalAmt'
            : (amount.trim().isNotEmpty && amount.trim() != '0'
                ? (amount.startsWith('₹') ? amount : '₹$amount')
                : 'Free');






    final IconData vehicleIcon = getVehicleIcon(vehicleType);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPrintAndExit
                                  ? 'Exit Completed'
                                  : 'Booking Confirmed',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (vendorName.trim().isNotEmpty)
                              Text(
                                vendorName.trim(),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey.shade500,
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Ticket Details Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Vehicle Number Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtils.primarycolor().withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ColorUtils.primarycolor().withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                vehicleIcon,
                                color: ColorUtils.primarycolor(),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  vehicleNumber.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: ColorUtils.primarycolor(),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (vehicleImages.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 120,
                              width: double.infinity,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (vehicleImages.first.startsWith('http'))
                                    Image.network(
                                      vehicleImages.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    )
                                  else
                                    Image.file(
                                      File(vehicleImages.first),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                    ),
                                  if (vehicleImages.length > 1)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '+${vehicleImages.length} photos',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Booking ID
                        _buildTicketInfoRow('Token / ID', displayId),
                        const Divider(height: 12),

                        // Vehicle Type
                        _buildTicketInfoRow('Vehicle Type', vehicleType),
                        const Divider(height: 12),

                        // Date & Time
                        _buildTicketInfoRow(
                          'Parked At',
                          '$parkingDate, $parkingTime',
                        ),
                        const Divider(height: 12),

                        if (isPrintAndExit &&
                            exitDate != null &&
                            exitDate.isNotEmpty) ...[
                          _buildTicketInfoRow(
                            'Exit At',
                            '$exitDate${(exitTime != null && exitTime.isNotEmpty) ? ', $exitTime' : ''}',
                          ),
                          const Divider(height: 12),
                        ],

                        // Plan
                        _buildTicketInfoRow('Plan', planLabel),
                        const Divider(height: 12),

                        // Total Amount (including valet if applicable)
                        if (isPrintAndExit) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.green.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      displayAmount,
                                      style: GoogleFonts.poppins(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.green.shade700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          _buildTicketInfoRow(
                            'Total Amount',
                            displayAmount,
                            valueColor: Colors.green.shade700,
                            isBold: true,
                          ),
                        ],











                        if (personName.trim().isNotEmpty) ...[
                          const Divider(height: 12),
                          _buildTicketInfoRow('Customer', personName.trim()),
                        ],

                        if (mobileNumber.trim().isNotEmpty) ...[
                          const Divider(height: 12),
                          _buildTicketInfoRow('Mobile', mobileNumber.trim()),
                        ],
                      ],
                    ),
                  ),

                  // QR Code (suppressed on Print and Exit as the vehicle is already exiting)
                  if (!isPrintAndExit && bookingId.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: PrettyQrView.data(
                            data: bookingId,
                            errorCorrectLevel: QrErrorCorrectLevel.M,
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
                  ] else ...[
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons: Print & Done
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Printing ticket...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            await UniversalPrintHelper.printTicket(
                              context: context,
                              vendorName: vendorName,
                              bookingId: bookingId,
                              invoiceId: invoiceId,
                              vehicleType: vehicleType,
                              vehicleNumber: vehicleNumber,
                              parkingDate: parkingDate,
                              parkingTime: parkingTime,
                              amount: amount,
                              personName: personName,
                              mobileNumber: mobileNumber,
                              valetCharge:
                                  appliedValetAmount > 0
                                      ? appliedValetAmount
                                      : null,
                              vendorId: vendorId ?? '',
                              bookType: bookType ?? '',
                              sts: receiptSts,
                              instantParkingReceipt: instantParkingReceipt,
                              isPrintAndExit: isPrintAndExit,
                            );
                          },
                          icon: const Icon(Icons.print, size: 16),
                          label: Text(
                            'Print',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ColorUtils.primarycolor(),
                            side: BorderSide(color: ColorUtils.primarycolor()),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, size: 16),
                          label: Text(
                            'Close',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorUtils.primarycolor(),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> showForBooking(
    BuildContext context,
    Bookingdata vehicle, {
    String? vendorId,
    String? defaultVendorName,
  }) async {
    final vName = effectivePrintVendorName(
      vehicle.vendorname,
      defaultVendorName,
    );

    final pDate = vehicle.parkingDate.isNotEmpty
        ? vehicle.parkingDate
        : vehicle.parkeddate.isNotEmpty
            ? vehicle.parkeddate
            : vehicle.bookingDate;

    final pTime = vehicle.parkingTime.isNotEmpty
        ? vehicle.parkingTime
        : vehicle.parkedtime.isNotEmpty
            ? vehicle.parkedtime
            : vehicle.bookingTime;

    String amt = vehicle.amount;
    if (amt.isEmpty || amt == '0' || amt == '0.0' || amt == '0.00') {
      if (vehicle.totalamout.isNotEmpty && vehicle.totalamout != '0') {
        amt = vehicle.totalamout;
      }
    }

    final double valetAmt = double.tryParse(vehicle.valetCharge) ?? 0.0;

    await show(
      context: context,
      vendorName: vName,
      bookingId: vehicle.id,
      invoiceId: vehicle.invoiceid,
      vehicleType: vehicle.vehicletype,
      vehicleNumber: vehicle.vehicleNumber,
      parkingDate: pDate,
      parkingTime: pTime,
      amount: amt,
      personName: vehicle.username,
      mobileNumber: vehicle.mobilenumber,
      receiptSts: vehicle.sts,
      appliedValetAmount: valetAmt,
      instantParkingReceipt: vehicle.sts.toLowerCase() == 'instant',
      vehicleImages: vehicle.vehicleImages,
      vendorId: vendorId ?? vehicle.Vendorid,
      bookType: vehicle.bookType,
    );
  }

  static Future<void> showForMap(
    BuildContext context,
    Map<String, dynamic> vehicle, {
    String? vendorId,
    String? defaultVendorName,
  }) async {
    final vName = effectivePrintVendorName(
      vehicle['vendorname']?.toString() ??
          vehicle['vendorName']?.toString() ??
          '',
      defaultVendorName,
    );

    final bookingId =
        vehicle['_id']?.toString() ?? vehicle['id']?.toString() ?? '';
    final invoiceId =
        vehicle['invoiceid']?.toString() ?? vehicle['invoiceId']?.toString();
    final vehicleType = vehicle['vehicleType']?.toString() ??
        vehicle['vehicletype']?.toString() ??
        'Car';
    final vehicleNumber = vehicle['vehicleNumber']?.toString() ??
        vehicle['vehiclenumber']?.toString() ??
        '';

    final pDate = vehicle['parkingDate']?.toString() ??
        vehicle['parkeddate']?.toString() ??
        vehicle['bookingDate']?.toString() ??
        '';
    final pTime = vehicle['parkingTime']?.toString() ??
        vehicle['parkedtime']?.toString() ??
        vehicle['bookingTime']?.toString() ??
        '';

    String amt = vehicle['amount']?.toString() ?? '';
    if (amt.isEmpty || amt == '0' || amt == '0.0' || amt == '0.00') {
      final total = vehicle['totalamout']?.toString() ??
          vehicle['totalAmount']?.toString() ??
          '';
      if (total.isNotEmpty && total != '0') {
        amt = total;
      }
    }

    final double valetAmt =
        double.tryParse(vehicle['valetCharge']?.toString() ?? '0') ?? 0.0;

    List<String> images = const [];
    if (vehicle['vehicleImages'] is List) {
      images =
          (vehicle['vehicleImages'] as List).map((e) => e.toString()).toList();
    }

    await show(
      context: context,
      vendorName: vName,
      bookingId: bookingId,
      invoiceId: invoiceId,
      vehicleType: vehicleType,
      vehicleNumber: vehicleNumber,
      parkingDate: pDate,
      parkingTime: pTime,
      amount: amt,
      personName: vehicle['username']?.toString() ?? '',
      mobileNumber: vehicle['mobilenumber']?.toString() ?? '',
      receiptSts: vehicle['sts']?.toString(),
      appliedValetAmount: valetAmt,
      instantParkingReceipt:
          (vehicle['sts']?.toString() ?? '').toLowerCase() == 'instant',
      vehicleImages: images,
      vendorId: vendorId ?? vehicle['vendorId']?.toString(),
      bookType: vehicle['bookType']?.toString(),
    );
  }
}
