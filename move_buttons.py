import re

with open('lib/auth/vendor/qrcodeallowparking.dart', 'r') as f:
    content = f.read()

# We need to remove the buttons from the top.
# They are located right after:
# Text(
#   bookingDetails?['vehicleNumber'] ??
#       'Unknown',
#   style: GoogleFonts.poppins(
#     fontSize: 14,
#     color: ColorUtils.primarycolor(),
#     fontWeight: FontWeight.bold,
#   ),
# ),
# const Spacer(),
# if (bookingDetails != null && ... 'PARKED' ...

# Let's find the start of `const Spacer(),` and remove it and the `if` block.

match = re.search(r'const\s+Spacer\(\),\s+if\s+\(bookingDetails\s+!=\s+null\s+&&\s+bookingDetails!\[\'status\'\]\s+==\s+\'PARKED\'\s+&&\s+bookingDetails!\[\'vendorId\'\]\.toString\(\)\s+==\s+widget\.vendorid\)', content)

if not match:
    print("Could not find the buttons block!")
    exit(1)

start_idx = match.start()

# Now find the first `Padding(` after the if statement
padding_idx = content.find('Padding(', match.end())

# Now we need to parse matching brackets to find the end of the `Padding` block
brace_count = 0
end_idx = -1
for i in range(padding_idx + len('Padding('), len(content)):
    if content[i] == '(':
        brace_count += 1
    elif content[i] == ')':
        if brace_count == 0:
            end_idx = i
            break
        brace_count -= 1

if end_idx == -1:
    print("Could not find end of padding block!")
    exit(1)

# Remove the block from start_idx to end_idx + 1 (the closing parenthesis of Padding)
content = content[:start_idx] + 'const SizedBox(width: 0),' + content[end_idx + 1:]

# Now we need to append the buttons below the card.
# We will insert them right before the return statement inside the Builder.
# Or rather, wrap the SizedBox (the card) in a Column.
# The card starts with: return SizedBox(
# Let's find: return SizedBox(

card_match = re.search(r'return SizedBox\(\s+height:\s+120,\s+child:\s+Stack\(', content)
if not card_match:
    print("Could not find the start of the card!")
    exit(1)

start_card_idx = card_match.start()

# We need to find the end of the `return SizedBox(...)` block.
brace_count = 0
end_card_idx = -1
for i in range(start_card_idx + len('return SizedBox('), len(content)):
    if content[i] == '(':
        brace_count += 1
    elif content[i] == ')':
        if brace_count == 0:
            # But it's `return SizedBox(...);` so we need to include the semicolon
            end_card_idx = i
            break
        brace_count -= 1

# Check for the semicolon
semicolon_idx = content.find(';', end_card_idx)
if semicolon_idx != -1 and semicolon_idx - end_card_idx < 5:
    end_card_idx = semicolon_idx

original_card = content[start_card_idx:end_card_idx + 1]
original_card_no_return = original_card.replace('return ', '', 1)
if original_card_no_return.endswith(';'):
    original_card_no_return = original_card_no_return[:-1]

buttons_ui = """
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
"""

wrapped_card = f"""return Column(
  children: [
    {original_card_no_return},
    {buttons_ui}
  ],
);"""

content = content[:start_card_idx] + wrapped_card + content[end_card_idx + 1:]

with open('lib/auth/vendor/qrcodeallowparking.dart', 'w') as f:
    f.write(content)

print("Successfully replaced!")
