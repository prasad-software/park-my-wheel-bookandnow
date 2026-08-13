
import "dart:io";

void main() {
  final file = File("lib/auth/vendor/vendorcreatebooking.dart");
  String content = file.readAsStringSync();
  
  // Replace the _buildActionButton calls
  content = content.replaceAll(
    "_buildActionButton(\n                            \"Book Now\",\n                            Icons.check_circle,\n                            ColorUtils.primarycolor(),\n                            _isLoading ? () {} : _registerParking,\n                            isDisabled: !_bookEnabled,\n                          ),",
    "_buildActionButton(\n                            \"Book Now\",\n                            Icons.check_circle,\n                            ColorUtils.primarycolor(),\n                            _registerParking,\n                            isDisabled: !_bookEnabled,\n                            isLoading: _isLoading,\n                          ),"
  );
  
  content = content.replaceAll(
    "_buildActionButton(\n                            \"Book and Print\",\n                            Icons.print,\n                            ColorUtils.primarycolor(),\n                            _bookAndPrint,\n                            isDisabled: !(_bookEnabled && _printEnabled),\n                          ),",
    "_buildActionButton(\n                            \"Book and Print\",\n                            Icons.print,\n                            ColorUtils.primarycolor(),\n                            _bookAndPrint,\n                            isDisabled: !(_bookEnabled && _printEnabled),\n                            isLoading: _isLoading,\n                          ),"
  );

  content = content.replaceAll(
    "_buildActionButton(\n                            \"Print and Exit\",\n                            Icons.exit_to_app,\n                            ColorUtils.primarycolor(),\n                            _isLoading ? () {} : _printAndExit,\n                            isDisabled: !(_printEnabled && _exitEnabled),\n                          ),",
    "_buildActionButton(\n                            \"Print and Exit\",\n                            Icons.exit_to_app,\n                            ColorUtils.primarycolor(),\n                            _printAndExit,\n                            isDisabled: !(_printEnabled && _exitEnabled),\n                            isLoading: _isLoading,\n                          ),"
  );
  
  file.writeAsStringSync(content);
  print("Button calls updated!");
}

