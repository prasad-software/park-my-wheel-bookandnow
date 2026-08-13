import 'dart:io';

void main() {
  final file = File('lib/auth/vendor/qrcodeallowparking.dart');
  String content = file.readAsStringSync();

  // Find the exact condition
  String searchStr = "if (bookingDetails != null &&";
  int idx = content.indexOf(searchStr);
  if (idx == -1) {
    print("Could not find if statement");
    return;
  }
  
  // Find "PARKED" condition to ensure it's the right one
  int idx2 = content.indexOf("widget.vendorid)", idx);
  if (idx2 == -1) {
    print("Could not find vendorid");
    return;
  }
  
  // Now find the Padding( that comes after this
  int paddingIdx = content.indexOf("Padding(", idx2);
  if (paddingIdx == -1) {
    print("Could not find Padding(");
    return;
  }

  // extract the padding block using brace matching
  int braceCount = 0;
  int endIdx = -1;
  for (int i = paddingIdx + "Padding(".length; i < content.length; i++) {
    if (content[i] == '(') braceCount++;
    if (content[i] == ')') {
      if (braceCount == 0) {
        endIdx = i;
        break;
      }
      braceCount--;
    }
  }

  if (endIdx == -1) {
    print("Could not find end of padding");
    return;
  }

  // The block to remove is from idx to endIdx + 1
  String paddingBlock = content.substring(paddingIdx, endIdx + 1);
  
  // We need to remove the buttons from the top
  content = content.replaceRange(idx, endIdx + 1, "const SizedBox(width: 0),");

  String buttonsUI = """
  if (bookingDetails != null && bookingDetails!['status'] == 'PARKED' && bookingDetails!['vendorId'].toString() == widget.vendorid)
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bookingDetails!['sts']?.toString() == 'Instant')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ElevatedButton(
                onPressed: _isExiting ? null : () => _handlePrintAndExit(bookingDetails!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: ColorUtils.primarycolor(),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(5)), side: BorderSide(color: ColorUtils.primarycolor(), width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isExiting) SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.primarycolor())))
                    else const Icon(Icons.check_circle_outline, color: Colors.black, size: 24),
                    const SizedBox(width: 10),
                    Text(_isExiting ? 'Processing...' : 'Print & Exit', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: ColorUtils.primarycolor())),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ElevatedButton(
              onPressed: (_isCheckingExit || _isExiting) ? null : () => _handleExitButtonPressed(bookingDetails!),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(5)), side: BorderSide(color: ColorUtils.primarycolor(), width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isCheckingExit) SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.primarycolor())))
                  else const Icon(Icons.qr_code_scanner, color: Colors.black, size: 24),
                  const SizedBox(width: 10),
                  Text(_isCheckingExit ? 'Checking...' : 'Exit', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final String bId = bookingDetails!['_id']?.toString() ?? '';
              if (bId.isEmpty) return;
              String currentAmount = '0';
              try { currentAmount = await UniversalPrintHelper.getPrintAmountFromAPI(bId); } catch (_) {}
              await UniversalPrintHelper.printTicket(
                context: context,
                vendorName: bookingDetails!['vendorName'] ?? 'Vendor',
                bookingId: bId,
                invoiceId: bookingDetails!['invoiceId']?.toString(),
                vehicleType: bookingDetails!['vehicleType'] ?? '',
                vehicleNumber: bookingDetails!['vehicleNumber'] ?? '',
                parkingDate: bookingDetails!['parkingDate'] ?? '',
                parkingTime: bookingDetails!['parkingTime'] ?? '',
                amount: currentAmount,
                personName: bookingDetails!['userName'] ?? bookingDetails!['personName'] ?? '',
                valetCharge: double.tryParse(bookingDetails!['valetCharge']?.toString() ?? '0') ?? 0.0,
                mobileNumber: bookingDetails!['mobileNumber'] ?? '',
                vendorId: bookingDetails!['vendorId']?.toString() ?? widget.vendorid,
                bookType: bookingDetails!['bookingType'] ?? bookingDetails!['bookType'] ?? '',
                sts: bookingDetails!['sts']?.toString() ?? '',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: ColorUtils.primarycolor(),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(5)), side: BorderSide(color: ColorUtils.primarycolor(), width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.print, color: Colors.black, size: 24),
                const SizedBox(width: 10),
                Text('Print', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: ColorUtils.primarycolor())),
              ],
            ),
          ),
        ],
      ),
    ),
  """;

  int bookingOnIdx = content.indexOf("'Booking on : ");
  if (bookingOnIdx == -1) {
    print("Could not find booking on text");
    return;
  }
  
  int returnIdx = content.lastIndexOf("return Container(", bookingOnIdx);
  if (returnIdx == -1) {
    returnIdx = content.lastIndexOf("return Padding(", bookingOnIdx);
  }
  if (returnIdx == -1) {
    print("Could not find return Container");
    return;
  }
  
  int cBraceCount = 0;
  int cEndIdx = -1;
  int startSearch = content.indexOf("(", returnIdx) + 1;
  
  for (int i = startSearch; i < content.length; i++) {
    if (content[i] == '(') cBraceCount++;
    if (content[i] == ')') {
      if (cBraceCount == 0) {
        cEndIdx = i;
        break;
      }
      cBraceCount--;
    }
  }
  
  if (cEndIdx == -1) {
    print("Could not find end of returned Container");
    return;
  }
  
  String originalCard = content.substring(returnIdx, cEndIdx + 1);
  String wrappedCard = '''return Column(
    children: [
      \${originalCard.substring(7)},
      \$buttonsUI
    ]
  )''';
  
  content = content.replaceRange(returnIdx, cEndIdx + 1, wrappedCard);
  
  // Also need to remove the spacer before the top buttons block if it exists
  content = content.replaceAll("const Spacer(),", "");
  
  file.writeAsStringSync(content);
  print('Successfully moved buttons!');
}
