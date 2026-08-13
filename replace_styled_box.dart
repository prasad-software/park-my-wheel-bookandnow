
import "dart:io";

void main() {
  final newStyledBox = """  Widget _styledBox(String value) {
    String displayValue = value;
    if (value.isNotEmpty) {
      final parts = value.split(":");
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final period = hour >= 12 ? "PM" : "AM";
        int hour12 = hour % 12;
        if (hour12 == 0) hour12 = 12;
        displayValue = \"\${hour12.toString().padLeft(2, \"0\")}:\${minute.toString().padLeft(2, \"0\")} \$period\";
      }
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        displayValue,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }""";

  final files = [
    "lib/explorebooknow.dart",
    "lib/auth/customer/drawer/listexplore.dart",
    "lib/auth/customer/dummypages/drawermyspace.dart",
    "lib/auth/customer/parking/bookparking.dart",
    "lib/auth/customer/parking/reschecule.dart",
    "lib/auth/vendor/vendorbottomnav/vendorprofile.dart"
  ];

  final oldPattern = RegExp(r"  Widget _styledBox\(String value\) \{\s*return Container\(\s*height: 30,\s*padding: const EdgeInsets\.symmetric\(horizontal: 6\),\s*decoration: BoxDecoration\(\s*border: Border\.all\(color: Colors\.grey\.shade300\),\s*borderRadius: BorderRadius\.circular\(4\),\s*\),\s*alignment: Alignment\.centerLeft,\s*child: Text\(\s*value,\s*style: const TextStyle\(fontSize: 11, color: Colors\.black87\),\s*\),\s*\);\s*\}");

  for (final filePath in files) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    
    String content = file.readAsStringSync();
    
    int matchCount = oldPattern.allMatches(content).length;
    if (matchCount > 0) {
      content = content.replaceAll(oldPattern, newStyledBox);
      file.writeAsStringSync(content);
      print("Updated \$filePath (\$matchCount instances)");
    } else {
      print("Could not find exact match in \$filePath");
    }
  }
}

