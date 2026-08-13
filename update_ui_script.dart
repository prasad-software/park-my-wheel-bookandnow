import 'dart:io';

void main() {
  var file = File('lib/auth/vendor/vendorcreatebooking.dart');
  var lines = file.readAsLinesSync();
  
  // 1. Find Optional Information block
  int startIndex = -1;
  int endIndex = -1;
  
  int optInfoTextIndex = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('"Optional Information"')) {
      optInfoTextIndex = i;
      break;
    }
  }
  
  if (optInfoTextIndex == -1) {
    print("Could not find Optional Information text.");
    return;
  }
  
  for (int i = optInfoTextIndex; i >= 0; i--) {
    if (lines[i].trim() == 'Row(') {
      startIndex = i;
      // if previous line is SizedBox(height: 10), include it
      if (i > 0 && lines[i-1].contains('const SizedBox(height: 10),')) {
        startIndex = i - 1;
      }
      break;
    }
  }

  if (startIndex == -1) {
    print("Could not find start of Optional Information block.");
    return;
  }

  int openBracketCount = 0;
  bool insideIfBlock = false;
  
  for (int i = startIndex; i < lines.length; i++) {
    if (!insideIfBlock && lines[i].contains('if (_showOptionalInfo)')) {
      insideIfBlock = true;
      openBracketCount = 1;
      continue;
    }
    
    if (insideIfBlock) {
      if (lines[i].contains('[')) openBracketCount++;
      if (lines[i].contains(']')) {
        openBracketCount--;
        if (openBracketCount == 0) {
          endIndex = i;
          break;
        }
      }
    }
  }

  if (endIndex == -1) {
    print("Could not find end of Optional Information block.");
    return;
  }
  
  print("Optional Information block from \$startIndex to \$endIndex");
  
  var optionalInfoBlock = lines.sublist(startIndex, endIndex + 1);
  lines.removeRange(startIndex, endIndex + 1);
  
  // 2. Find insertion point below QR code
  int insertIndex = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains("if (_paymentMode == 'Online') _buildInlineUpiQr(),")) {
      // Find the const SizedBox(height: 10), after it
      for (int j = i + 1; j < lines.length; j++) {
        if (lines[j].contains('const SizedBox(height: 10),')) {
          insertIndex = j + 1;
          break;
        }
      }
      break;
    }
  }
  
  if (insertIndex == -1) {
    print("Could not find insertion point for Optional Information.");
    return;
  }
  
  lines.insertAll(insertIndex, optionalInfoBlock);
  print("Moved Optional Information block to line \$insertIndex.");
  
  // 3. Find AppBar actions and insert scan icon
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('actions: [')) {
      if (!lines[i + 1].contains('Icons.qr_code_scanner')) {
        var scanIconButton = '''
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => qrcodeallowpark(
                                  vendorid: widget.vendorid,
                                ),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.qr_code_scanner,
                        color: Colors.red,
                      ),
                    ),''';
        lines.insert(i + 1, scanIconButton);
        print("Inserted scan icon in AppBar.");
      }
      break;
    }
  }
  
  // 4. Add import at the top
  bool hasImport = false;
  for (int i = 0; i < 50; i++) {
    if (lines[i].contains('qrcodeallowparking.dart')) {
      hasImport = true;
      break;
    }
  }
  
  if (!hasImport) {
    lines.insert(0, "import 'package:mywheels/auth/vendor/qrcodeallowparking.dart';");
    print("Added import.");
  }
  
  file.writeAsStringSync(lines.join('\n'));
  print("Done updating vendorcreatebooking.dart");
}
