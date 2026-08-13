import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/config/colorcode.dart';

class FilterScreen extends StatefulWidget {
  final List<Map<String, dynamic>> vendors;
  final Function(List<Map<String, dynamic>>, Map<String, dynamic>) onApply;

  const FilterScreen({super.key, required this.vendors, required this.onApply});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  String? selectedVehicle;
  String? selectedBookingType;
  String? sortBy;

  final List<String> vehicles = ['Cars', 'Bikes', 'Others'];
  final List<String> bookingTypes = ['Instant', 'Fullday', 'Schedule', 'Monthly'];
  final List<String> sortOptions = [
    'Distance (Low to High)',
    'Distance (High to Low)',
    'Price(Low to High)',
    'Price(High to Low)',
  ];

  void _applyFilters() {
    List<Map<String, dynamic>> filteredVendors = List.from(widget.vendors);

    print('Initial vendors count: ${filteredVendors.length}');
    print('Raw vendors data: ${filteredVendors.map((v) => {
      'vendorName': v['vendorName'],
      'charges': v['charges'],
      'parkingEntries': v['parkingEntries']
    }).toList()}');
    print('Selected vehicle: $selectedVehicle, Selected booking type: $selectedBookingType, Sort by: $sortBy');

    // Vehicle filter based on parkingEntries
    if (selectedVehicle != null) {
      print('Applying vehicle filter for: $selectedVehicle');
      filteredVendors = filteredVendors.where((vendor) {
        final parkingEntries = vendor['parkingEntries'] as List<dynamic>?;
        if (parkingEntries == null || parkingEntries.isEmpty) return false;

        return parkingEntries.any((entry) =>
        entry['type']?.toString().toLowerCase() == selectedVehicle!.toLowerCase());
      }).toList();
      print('Vendors after vehicle filter: ${filteredVendors.length}');
    }

    // Booking type filter using charges
    if (selectedBookingType != null) {
      print('Applying booking type filter for: $selectedBookingType');
      filteredVendors = filteredVendors.where((vendor) {
        final charges = vendor['charges'] as Map<String, dynamic>?;
        if (charges == null || charges.isEmpty) return false;

        String bookingTypeKey = selectedBookingType!.toLowerCase();

        if (selectedVehicle != null) {
          String vehiclePrefix;
          switch (selectedVehicle!.toLowerCase()) {
            case 'cars':
              vehiclePrefix = 'car';
              break;
            case 'bikes':
              vehiclePrefix = 'bike';
              break;
            case 'others':
              vehiclePrefix = 'others';
              break;
            default:
              vehiclePrefix = '';
          }

          String chargeKey = '$vehiclePrefix${_capitalizeBookingKey(bookingTypeKey)}';
          return charges.containsKey(chargeKey) && charges[chargeKey] != null;
        } else {
          // If no vehicle selected, allow any charge that ends with the booking type
          return charges.keys.any((key) => key.toLowerCase().endsWith(bookingTypeKey));
        }
      }).toList();
      print('Vendors after booking type filter: ${filteredVendors.length}');
    }

    // Sorting
    if (sortBy != null) {
      print('Applying sorting: $sortBy');
      filteredVendors.sort((a, b) {
        double distanceA = a['distance'] ?? double.infinity;
        double distanceB = b['distance'] ?? double.infinity;

        double priceA = double.infinity;
        double priceB = double.infinity;

        if (selectedBookingType != null) {
          String bookingTypeKey = selectedBookingType!.toLowerCase();

          if (selectedVehicle != null) {
            String vehiclePrefix;
            switch (selectedVehicle!.toLowerCase()) {
              case 'cars':
                vehiclePrefix = 'car';
                break;
              case 'bikes':
                vehiclePrefix = 'bike';
                break;
              case 'others':
                vehiclePrefix = 'others';
                break;
              default:
                vehiclePrefix = '';
            }

            String chargeKey = '$vehiclePrefix${_capitalizeBookingKey(bookingTypeKey)}';
            priceA = a['charges']?[chargeKey]?['amount'] != null
                ? double.tryParse(a['charges'][chargeKey]['amount'].toString()) ?? double.infinity
                : double.infinity;
            priceB = b['charges']?[chargeKey]?['amount'] != null
                ? double.tryParse(b['charges'][chargeKey]['amount'].toString()) ?? double.infinity
                : double.infinity;
          } else {
            // Fallback: use the lowest matching booking type price for each vendor
            priceA = _getLowestMatchingCharge(a['charges'], bookingTypeKey);
            priceB = _getLowestMatchingCharge(b['charges'], bookingTypeKey);
          }
        }

        switch (sortBy) {
          case 'Distance (Low to High)':
            return distanceA.compareTo(distanceB);
          case 'Distance (High to Low)':
            return distanceB.compareTo(distanceA);
          case 'Price(Low to High)':
            return priceA.compareTo(priceB);
          case 'Price(High to Low)':
            return priceB.compareTo(priceA);
          default:
            return 0;
        }
      });
      print('Vendors after sorting: ${filteredVendors.map((v) => v['vendorName']).toList()}');
    }

    // Final result
    print('Final filtered vendors count: ${filteredVendors.length}');
    widget.onApply(filteredVendors, {
      'vehicle': selectedVehicle,
      'bookingType': selectedBookingType,
      'sortBy': sortBy,
    });

    if (filteredVendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No vendors found for the selected filters.',
            style: GoogleFonts.poppins(),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
  String _capitalizeBookingKey(String key) {
    if (key.isEmpty) return key;
    return key[0].toUpperCase() + key.substring(1);
  }

  double _getLowestMatchingCharge(Map<String, dynamic>? charges, String bookingTypeKey) {
    if (charges == null) return double.infinity;

    double minPrice = double.infinity;

    charges.forEach((key, value) {
      if (key.toLowerCase().endsWith(bookingTypeKey) && value['amount'] != null) {
        double price = double.tryParse(value['amount'].toString()) ?? double.infinity;
        if (price < minPrice) {
          minPrice = price;
        }
      }
    });

    return minPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter & Sort',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.primarycolor(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vehicle Type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vehicle Type',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.directions_car,size: 16,),
                tooltip: 'Clear Vehicle Filter',
                onPressed: () => setState(() => selectedVehicle = null),
              ),
            ],
          ),
          // const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: vehicles.map((vehicle) => ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.0), // Reduce vertical padding
                child: Text(
                  vehicle,
                  style: GoogleFonts.poppins(
                    fontSize: 12, // Smaller font size
                    color: selectedVehicle == vehicle ? Colors.white : Colors.black,
                  ),
                ),
              ),
              selected: selectedVehicle == vehicle,
              selectedColor: ColorUtils.primarycolor(),
              backgroundColor: Colors.white,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Shrinks tap area
              visualDensity: VisualDensity.compact, // Makes chip more compact
              onSelected: (selected) {
                setState(() {
                  selectedVehicle = selected ? vehicle : null;
                });
              },
            )).toList(),
          ),

          const SizedBox(height: 5),

          // Booking Type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Booking Type',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.schedule,size: 16,),
                tooltip: 'Clear Booking Type Filter',
                onPressed: () => setState(() => selectedBookingType = null),
              ),
            ],
          ),
          // const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bookingTypes.map((type) => ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.0), // Reduced vertical padding
                child: Text(
                  type,
                  style: GoogleFonts.poppins(
                    fontSize: 12, // Smaller text
                    color: selectedBookingType == type ? Colors.white : Colors.black,
                  ),
                ),
              ),
              selected: selectedBookingType == type,
              selectedColor: ColorUtils.primarycolor(),
              backgroundColor: Colors.white,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduces tap area padding
              visualDensity: VisualDensity.compact, // Makes chip more compact
              onSelected: (selected) {
                setState(() {
                  selectedBookingType = selected ? type : null;
                });
              },
            )).toList(),
          ),

          // const SizedBox(height: 5),

          // Sort By
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sort By',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sort,size: 16,),
                tooltip: 'Clear Sorting',
                onPressed: () => setState(() => sortBy = null),
              ),
            ],
          ),
          // const SizedBox(height: 8),
          Wrap(
            spacing: 0,
            children: sortOptions.map((option) {
              IconData icon;
              if (option.contains('Distance') && option.contains('Low')) {
                icon = Icons.arrow_drop_up;
              } else if (option.contains('Distance') && option.contains('High')) {
                icon = Icons.arrow_drop_down;
              } else if (option.contains('Price') && option.contains('Low')) {
                icon = Icons.arrow_drop_up;
              } else if (option.contains('Price') && option.contains('High')) {
                icon = Icons.arrow_drop_down;
              } else {
                icon = Icons.filter_alt;
              }

              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // const SizedBox(width: 4),
                    Text(
                      option,
                      style: GoogleFonts.poppins(
                        color: sortBy == option ? Colors.white : Colors.black,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(icon, size: 18, color: sortBy == option ? Colors.white : Colors.black),
                  ],
                ),
                selected: sortBy == option,
                selectedColor: ColorUtils.primarycolor(),
                backgroundColor: Colors.white,
                onSelected: (selected) {
                  setState(() {
                    sortBy = selected ? option : null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      selectedVehicle = null;
                      selectedBookingType = null;
                      sortBy = null;
                    });
                    widget.onApply(List.from(widget.vendors), {
                      'vehicle': null,
                      'bookingType': null,
                      'sortBy': null,
                    });
                  },
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, color: Colors.red, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Clear All',
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primarycolor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Apply Filters',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class ParkingCharge {
  final String vehicleType;
  final String type;
  final double amount;

  ParkingCharge({required this.vehicleType, required this.type, required this.amount});

  factory ParkingCharge.fromJson(Map<String, dynamic> json) {
    return ParkingCharge(
      vehicleType: json['vehicleType'] ?? '',
      type: json['type'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
    );
  }
}