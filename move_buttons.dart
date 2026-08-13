import 'dart:io';

void main() {
  final file = File('lib/auth/vendor/qrcodeallowparking.dart');
  String content = file.readAsStringSync();

  // Find the exact match for `const Spacer(),` and the `if` condition using regex or simple substring search
  int spacerIdx = content.indexOf('const Spacer(),');
  if (spacerIdx == -1) {
    print("Could not find Spacer");
    return;
  }
  
  // Find where it ends
  int parkedIdx = content.indexOf("'PARKED'", spacerIdx);
  int paddingIdx = content.indexOf("Padding(", parkedIdx);
  if (paddingIdx == -1) {
    print("Could not find Padding");
    return;
  }
  
  // Find the end of this Padding block
  int braceCount = 0;
  int endPaddingIdx = -1;
  // paddingIdx + 8 is the character AFTER 'Padding('
  for (int i = paddingIdx + 8; i < content.length; i++) {
    if (content[i] == '(') braceCount++;
    else if (content[i] == ')') {
      if (braceCount == 0) {
        endPaddingIdx = i;
        break;
      }
      braceCount--;
    }
  }

  if (endPaddingIdx == -1) {
    print("Could not find end of padding block");
    return;
  }
  
  // Remove the block
  content = content.replaceRange(spacerIdx, endPaddingIdx + 1, 'const SizedBox(width: 0),');
  
  // Find card start: return SizedBox(
  int cardIdx = content.indexOf('return SizedBox(');
  if (cardIdx == -1) {
    print("Could not find card start");
    return;
  }
  
  // Find card end
  braceCount = 0;
  int endCardIdx = -1;
  // cardIdx + 16 is the character AFTER 'return SizedBox('
  for (int i = cardIdx + 16; i < content.length; i++) {
    if (content[i] == '(') braceCount++;
    else if (content[i] == ')') {
      if (braceCount == 0) {
        endCardIdx = i;
        break;
      }
      braceCount--;
    }
  }
  
  if (endCardIdx == -1) {
    print("Could not find end of card");
    return;
  }
  
  int semiIdx = content.indexOf(';', endCardIdx);
  if (semiIdx != -1 && semiIdx - endCardIdx < 5) {
    endCardIdx = semiIdx;
  }
  
  String originalCard = content.substring(cardIdx, endCardIdx + 1);
  String originalCardNoReturn = originalCard.replaceFirst('return ', '');
  if (originalCardNoReturn.endsWith(';')) {
    originalCardNoReturn = originalCardNoReturn.substring(0, originalCardNoReturn.length - 1);
  }
  
  String buttonsUI = """
if (bookingDetails != null && bookingDetails!['status'] == 'PARKED' && bookingDetails!['vendorId'].toString() == widget.vendorid)
  Padding(
    padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bookingDetails!['sts']?.toString() == 'Instant')
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: ElevatedButton(
              onPressed: _isExiting ? null : () => _handlePrintAndExit(bookingDetails!),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: ColorUtils.primarycolor(),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  side: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isExiting)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.primarycolor()),
                      ),
                    )
                  else
                    const Icon(Icons.check_circle_outline, color: Colors.black, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _isExiting ? 'Processing...' : 'Print & Exit',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ColorUtils.primarycolor(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: ElevatedButton(
            onPressed: (_isCheckingExit || _isExiting) ? null : () => _handleExitButtonPressed(bookingDetails!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(5)),
                side: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isCheckingExit)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(ColorUtils.primarycolor()),
                    ),
                  )
                else
                  const Icon(Icons.qr_code_scanner, color: Colors.black, size: 24),
                const SizedBox(width: 10),
                Text(
                  _isCheckingExit ? 'Checking...' : 'Exit',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            final String bId = bookingDetails!['_id']?.toString() ?? '';
            if (bId.isEmpty) return;
            String currentAmount = '0';
            try {
              currentAmount = await UniversalPrintHelper.getPrintAmountFromAPI(bId);
            } catch (_) {}
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
            backgroundColor: Colors.white,
            foregroundColor: ColorUtils.primarycolor(),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              side: BorderSide(color: ColorUtils.primarycolor(), width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.print, color: Colors.black, size: 24),
              const SizedBox(width: 10),
              Text(
                'Print',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.primarycolor(),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  )
""";

  String wrappedCard = '''return Column(
  children: [
    \$originalCardNoReturn,
    \$buttonsUI
  ],
);''';

  content = content.replaceRange(cardIdx, endCardIdx + 1, wrappedCard);
  file.writeAsStringSync(content);
  print('Successfully executed!');
}
