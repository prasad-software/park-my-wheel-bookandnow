import 'dart:convert';
import 'package:bottom_picker/bottom_picker.dart';
import 'package:bottom_picker/resources/arrays.dart' show BottomPickerTheme;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mywheels/auth/customer/parking/parking.dart';
import 'package:mywheels/auth/vendor/vendorcreatebooking.dart';
import 'package:mywheels/auth/vendor/vendordash.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../../config/authconfig.dart';
import '../../../config/colorcode.dart';
import 'package:http/http.dart' as http;
import 'package:mywheels/utils/sts_utils.dart';

import '../../customer/parking/parkindetails.dart';
class managebooking extends StatefulWidget {
  final String vendorid;
  const managebooking({super.key,
    required this.vendorid,
  });
  @override
  _managebookingScreenState createState() => _managebookingScreenState();
}
class _managebookingScreenState extends State<managebooking>with SingleTickerProviderStateMixin {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  late TabController _tabController;

  List<Bookingdata> _cars = [];
  List<Bookingdata> _bikes = [];
  List<Bookingdata> _others = [];
  bool _isFetching = false;
  String? _fetchError;

  void _selectDate(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: SizedBox(
            width: 300,
            height: 300,
            child: SfDateRangePicker(
                backgroundColor: Colors.white,
                selectionColor: ColorUtils.primarycolor(),
                startRangeSelectionColor: ColorUtils.primarycolor(),
                endRangeSelectionColor: ColorUtils.primarycolor(),
                rangeSelectionColor:ColorUtils.primarycolor().withOpacity(0.3),
                todayHighlightColor: ColorUtils.primarycolor(),
                selectionMode: DateRangePickerSelectionMode.range,
                minDate: DateTime(2001, 1, 1),
                maxDate: DateTime(2099, 1, 1),

                headerStyle: const DateRangePickerHeaderStyle(
                  backgroundColor: Colors.white,
                  textStyle: TextStyle(color: Colors.black, fontSize: 18),
                ),

                monthViewSettings: const DateRangePickerMonthViewSettings(
                  viewHeaderStyle: DateRangePickerViewHeaderStyle(
                    backgroundColor: Colors.white,
                    textStyle: TextStyle(color: Colors.black),
                  ),
                ),
                monthCellStyle: DateRangePickerMonthCellStyle(
                  todayCellDecoration: BoxDecoration(
                    color: ColorUtils.primarycolor().withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  disabledDatesDecoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  textStyle: const TextStyle(color: Colors.black),
                  todayTextStyle: const TextStyle(color: Colors.white),
                ),

                onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                  if (args.value is PickerDateRange) {
                    setState(() {
                      _startDate = args.value.startDate;
                      _endDate = args.value.endDate ?? args.value.startDate;
                    });
                  }
                }
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _startDateController.text = DateFormat('dd-MM-yyyy').format(_startDate);
                  _endDateController.text = DateFormat('dd-MM-yyyy').format(_endDate);
                });
                Navigator.of(context).pop();
                _fetchManageBookings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.primarycolor(),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                minimumSize: const Size(40, 35),
              ),
              child: const Text(
                "OK",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _fetchManageBookings() async {
    setState(() { _isFetching = true; _fetchError = null; });
    final start = DateFormat('dd-MM-yyyy').format(_startDate);
    final end = DateFormat('dd-MM-yyyy').format(_endDate);
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}vendor/fast-manage/${widget.vendorid}?startDate=$start&endDate=$end'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List carsList = data['cars'] ?? [];
        final List bikesList = data['bikes'] ?? [];
        final List othersList = data['others'] ?? [];
        if (mounted) {
          setState(() {
            _cars = carsList.map((e) => Bookingdata.fromJson(e as Map<String, dynamic>)).toList();
            _bikes = bikesList.map((e) => Bookingdata.fromJson(e as Map<String, dynamic>)).toList();
            _others = othersList.map((e) => Bookingdata.fromJson(e as Map<String, dynamic>)).toList();
            _isFetching = false;
          });
        }
      } else {
        if (mounted) setState(() { _fetchError = 'Failed to load bookings'; _isFetching = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _fetchError = e.toString(); _isFetching = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _startDateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(_startDate),
    );
    _endDateController = TextEditingController(
      text: DateFormat('dd-MM-yyyy').format(_endDate),
    );
    _fetchManageBookings();
  }

  @override
  void dispose() {

    _tabController.dispose(); // Clean up the controller when not in use
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {

    return Scaffold(backgroundColor: Colors.white,

      appBar: AppBar(titleSpacing: 0,
        backgroundColor: ColorUtils.secondarycolor(),
        title:  Text(
          'Manage Bookings',
          style:   GoogleFonts.poppins(color: Colors.black,fontSize: 18),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black, // Set the color of the back icon to white
        ),
        actions: [
          IconButton(
            onPressed: () {
              _selectDate(context);

            },
            icon:  Icon(Icons. calendar_month_outlined, color: ColorUtils.primarycolor(),), // Set the icon here

          ),
          const SizedBox(width: 10,),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F2F3),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10), // Rounded corners only at the top
                        topRight: Radius.circular(10),
                      ),
                      // border: Border.all(
                      //   color: ColorUtils.primarycolor(), // Red border color
                      //   width: 0.5,
                      // ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 39,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                          ),
                          child: TabBar(
                            dividerHeight: 0,
                            controller: _tabController,
                            indicator: RoundedRectIndicator(
                              color: const Color(0xFFF1F2F3),
                              radius: 8,
                            ),
                            tabs: [
                              Tab(child: CustomTab(text: "Cars", isSelected: _tabController.index == 0)),
                              Tab(child: CustomTab(text: "Bikes", isSelected: _tabController.index == 1)),
                              Tab(child: CustomTab(text: "Others", isSelected: _tabController.index == 2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerRight, // Aligns the content to the right
                          child: Row(
                            mainAxisSize: MainAxisSize.min, // Ensures the row size is based on content
                            children: [
                              Container(
                                child: Text(
                                  " ${_startDateController.text}",
                                  style:   GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                child:  Text(
                                  " to",
                                  style:   GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                child: Text(
                                  " ${_endDateController.text}",
                                  style:   GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                        ),
                        // Container(child: Text("end date:"),),


                        Container(
                          color: const Color(0xFFF1F2F3),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height - kToolbarHeight - 39 - 10, // Adjust height
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                manageCarsTab(vendorid: widget.vendorid, bookings: _cars, isLoading: _isFetching, error: _fetchError),
                                managebiketab(vendorid: widget.vendorid, bookings: _bikes, isLoading: _isFetching, error: _fetchError),
                                manageothers(vendorid: widget.vendorid, bookings: _others, isLoading: _isFetching, error: _fetchError),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),








    );
  }



}
class manageCarsTab extends StatefulWidget {
  final String vendorid;
  final List<Bookingdata> bookings;
  final bool isLoading;
  final String? error;
  const manageCarsTab({super.key, required this.vendorid, required this.bookings, required this.isLoading, this.error});
  @override
  _CarsTabState createState() => _CarsTabState();
}

class _CarsTabState extends State<manageCarsTab> {
  String _fmtBookingDT(String date, String time) {
    try {
      return DateFormat('d MMM, yyyy, hh:mm a').format(DateFormat('dd-MM-yyyy hh:mm a').parse('$date $time'));
    } catch (_) { return 'N/A'; }
  }
  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return const Column(children: [SizedBox(height: 50), Center(child: CircularProgressIndicator())]);
    if (widget.error != null) return Center(child: Text(widget.error!));
    if (widget.bookings.isEmpty) return const Column(children: [SizedBox(height: 100), Center(child: Text('No data available.'))]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      child: ListView.builder(
        itemCount: widget.bookings.length,
        itemBuilder: (context, index) {
          final vehicle = widget.bookings[index];
          final bookcom = _fmtBookingDT(vehicle.bookingDate, vehicle.bookingTime);
          final formattedDateTime = _fmtBookingDT(vehicle.parkingDate, vehicle.parkingTime);
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => vendorParkingDetails(
              parkeddate: vehicle.parkeddate, parkedtime: vehicle.parkedtime,
              subscriptionenddate: vehicle.subscriptionenddate,
              exitdate: vehicle.exitvehicledate, exittime: vehicle.exitvehicletime,
              invoiceid: vehicle.invoiceid, username: vehicle.username,
              amount: vehicle.amount, totalamount: vehicle.totalamout, invoice: vehicle.invoice,
              mobilenumber: vehicle.mobilenumber, sts: vehicle.sts,
              bookingtype: vehicle.bookingtype, otp: vehicle.otp,
              vehiclenumber: vehicle.vehicleNumber, vendorname: vehicle.vendorname,
              vendorid: vehicle.Vendorid, parkingdate: vehicle.parkingDate,
              parkingtime: vehicle.parkingTime, bookedid: vehicle.id,
              bookeddate: formattedDateTime, schedule: bookcom,
              status: vehicle.status, vehicletype: vehicle.vehicletype,
            ))),
            child: BookingCard(vehicle: vehicle, onRefresh: () => setState(() {})),
          );
        },
      ),
    );
  }
}


class managebiketab extends StatefulWidget {
  final String vendorid;
  final List<Bookingdata> bookings;
  final bool isLoading;
  final String? error;
  const managebiketab({super.key, required this.vendorid, required this.bookings, required this.isLoading, this.error});
  @override
  _managebikeState createState() => _managebikeState();
}

class _managebikeState extends State<managebiketab> {
  String _fmtDT(String date, String time) {
    try { return DateFormat('d MMM, yyyy, hh:mm a').format(DateFormat('dd-MM-yyyy hh:mm a').parse('$date $time')); }
    catch (_) { return 'N/A'; }
  }
  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return const Column(children: [SizedBox(height: 50), Center(child: CircularProgressIndicator())]);
    if (widget.error != null) return Center(child: Text(widget.error!));
    if (widget.bookings.isEmpty) return const Column(children: [SizedBox(height: 100), Center(child: Text('No data available.'))]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      child: ListView.builder(
        itemCount: widget.bookings.length,
        itemBuilder: (context, index) {
          final vehicle = widget.bookings[index];
          final bookcom = _fmtDT(vehicle.bookingDate, vehicle.bookingTime);
          final formattedDateTime = _fmtDT(vehicle.parkingDate, vehicle.parkingTime);
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => vendorParkingDetails(
              parkeddate: vehicle.parkeddate, parkedtime: vehicle.parkedtime,
              subscriptionenddate: vehicle.subscriptionenddate,
              exitdate: vehicle.exitvehicledate, exittime: vehicle.exitvehicletime,
              invoiceid: vehicle.invoiceid, username: vehicle.username,
              amount: vehicle.amount, totalamount: vehicle.totalamout, invoice: vehicle.invoice,
              mobilenumber: vehicle.mobilenumber, sts: vehicle.sts,
              bookingtype: vehicle.bookingtype, otp: vehicle.otp,
              vehiclenumber: vehicle.vehicleNumber, vendorname: vehicle.vendorname,
              vendorid: vehicle.Vendorid, parkingdate: vehicle.parkingDate,
              parkingtime: vehicle.parkingTime, bookedid: vehicle.id,
              bookeddate: formattedDateTime, schedule: bookcom,
              status: vehicle.status, vehicletype: vehicle.vehicletype,
            ))),
            child: BookingCard(vehicle: vehicle, onRefresh: () => setState(() {})),
          );
        },
      ),
    );
  }
}

class manageothers extends StatefulWidget {
  final String vendorid;
  final List<Bookingdata> bookings;
  final bool isLoading;
  final String? error;
  const manageothers({super.key, required this.vendorid, required this.bookings, required this.isLoading, this.error});
  @override
  _manageothersState createState() => _manageothersState();
}

class _manageothersState extends State<manageothers> {
  String _fmtDT(String date, String time) {
    try { return DateFormat('d MMM, yyyy, hh:mm a').format(DateFormat('dd-MM-yyyy hh:mm a').parse('$date $time')); }
    catch (_) { return 'N/A'; }
  }
  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return const Column(children: [SizedBox(height: 50), Center(child: CircularProgressIndicator())]);
    if (widget.error != null) return Center(child: Text(widget.error!));
    if (widget.bookings.isEmpty) return const Column(children: [SizedBox(height: 100), Center(child: Text('No data available.'))]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      child: ListView.builder(
        itemCount: widget.bookings.length,
        itemBuilder: (context, index) {
          final vehicle = widget.bookings[index];
          final bookcom = _fmtDT(vehicle.bookingDate, vehicle.bookingTime);
          final formattedDateTime = _fmtDT(vehicle.parkingDate, vehicle.parkingTime);
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => vendorParkingDetails(
              parkeddate: vehicle.parkeddate, parkedtime: vehicle.parkedtime,
              subscriptionenddate: vehicle.subscriptionenddate,
              exitdate: vehicle.exitvehicledate, exittime: vehicle.exitvehicletime,
              invoiceid: vehicle.invoiceid, username: vehicle.username,
              amount: vehicle.amount, totalamount: vehicle.totalamout, invoice: vehicle.invoice,
              mobilenumber: vehicle.mobilenumber, sts: vehicle.sts,
              bookingtype: vehicle.bookingtype, otp: vehicle.otp,
              vehiclenumber: vehicle.vehicleNumber, vendorname: vehicle.vendorname,
              vendorid: vehicle.Vendorid, parkingdate: vehicle.parkingDate,
              parkingtime: vehicle.parkingTime, bookedid: vehicle.id,
              bookeddate: formattedDateTime, schedule: bookcom,
              status: vehicle.status, vehicletype: vehicle.vehicletype,
            ))),
            child: BookingCard(vehicle: vehicle, onRefresh: () => setState(() {})),
          );
        },
      ),
    );
  }
}

class BookingCard extends StatefulWidget {
  final Bookingdata vehicle;
  final VoidCallback onRefresh;

  const BookingCard({
    super.key,
    required this.vehicle,
    required this.onRefresh,
  });

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  DateTime? selectedDateTime;
  String _formatDateTime(DateTime dateTime) {
    return DateFormat("dd-MM-yyyy hh:mm a").format(dateTime);  // Full date + time with AM/PM
  }
  Color customTeal = ColorUtils.primarycolor();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController checkout = TextEditingController();
  final TextEditingController reschedule = TextEditingController();
  final FocusNode _subscriptionFocusNode = FocusNode();
  bool _isLoading=false;
  void _showDateTimePickerForSubscription() {
    DateTime now = DateTime.now();
    DateTime initialDateTime = now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: BottomPicker.dateTime(
              initialDateTime: initialDateTime,
              minDateTime: DateTime(now.year, now.month, now.day), // Allow today's date
              maxDateTime: DateTime(2099, 12, 31),
              pickerTitle: Text(_formatDateTime(initialDateTime)),
              onSubmit: (dateTime) {
                DateTime currentNow = DateTime.now(); // Refresh the current time
                if (dateTime.year == currentNow.year &&
                    dateTime.month == currentNow.month &&
                    dateTime.day == currentNow.day &&
                    dateTime.isBefore(currentNow)) {
                  // Restrict past times only on the current day
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Cannot select a past time today!")),
                  );
                  return;
                }
                setState(() {
                  selectedDateTime = dateTime;
                  dateController.text = DateFormat("dd-MM-yyyy").format(dateTime); // Set date
                  timeController.text = DateFormat("hh:mm a").format(dateTime); // Set time
                  checkout.text = _formatDateTime(dateTime); // Set date and time in the text box
                  reschedule.text = _formatDateTime(dateTime); // Update the reschedule text controller
                  print("Selected Date: ${dateController.text}, Selected Time: ${timeController.text}"); // Debugging line
                });
              },
              bottomPickerTheme: BottomPickerTheme.temptingAzure,
            ),
          ),
        );
      },
    );
  }
  Future<void> _reshedule() async {

    // Format the date and time
    String formattedDate = DateFormat("dd-MM-yyyy").format(selectedDateTime!);
    String formattedTime = DateFormat("hh:mm a").format(selectedDateTime!);
    DateTime now = DateTime.now();

    try {

      // Prepare the data to send
      var data = {
        'userid': widget.vehicle.userid,
        'bookingDate': DateFormat("dd-MM-yyyy").format(now),
        'parkingDate': formattedDate,
        'parkingTime': formattedTime,
        'bookingTime': DateFormat("hh:mm a").format(now),
        'status':"PENDING"

      };

      // Debugging: Print the data being sent
      print('Sending data to server: $data');

      setState(() {
        _isLoading = true;
      });

      var response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}updaterescheule/${widget.vehicle.id}'),
        body: jsonEncode(data),
        headers: {"Content-Type": "application/json"},
      );

      // Debugging: Print the response status and body
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parking rescheduled successfully!')),
        );

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to register parking: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error connecting to server')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    final bool isApproved = widget.vehicle.status == "Approved";
    final bool hasPrintButton = widget.vehicle.status == "PARKED" ||
        widget.vehicle.status.toUpperCase() == 'COMPLETED';
    return SizedBox(
      height: isApproved ? 130 : (hasPrintButton ? 145 : 120),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 30,
            right: 0,
            child: Container(
              height: isApproved ? 100 : (hasPrintButton ? 115 : 80),
              decoration: BoxDecoration(
                color: widget.vehicle.status == 'Cancelled'
                    ? Colors.red
                    : ColorUtils.primarycolor(),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Text(
                  ' ${widget.vehicle.parkingDate}, ${widget.vehicle.parkingTime}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(5),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(
                          left: 14,
                          top: 2,
                          right: 0.0,
                          bottom: 0.0),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: widget.vehicle.status == 'Cancelled'
                                ? Colors.red
                                : ColorUtils.primarycolor(),
                            width: 0.5,
                          ),
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(5.0),
                          topRight: Radius.circular(5.0),
                        ),
                        color: widget.vehicle.status == 'Cancelled'
                            ? Colors.white
                            : Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.vehicle.vehicleNumber,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: widget.vehicle.status == 'Cancelled'
                                  ? Colors.red
                                  : ColorUtils.primarycolor(),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (widget.vehicle.status == "Cancelled")
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Text(
                                " ${widget.vehicle.cancelledStatus}",
                                style: GoogleFonts.poppins(
                                    color: widget.vehicle.status == 'Cancelled'
                                        ? Colors.red
                                        : ColorUtils.primarycolor(),
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          if (widget.vehicle.cancelledStatus?.isEmpty ?? true)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Text(
                                " ${widget.vehicle.status}",
                                style: GoogleFonts.poppins(
                                  color: widget.vehicle.status == 'Cancelled'
                                      ? Colors.red
                                      : ColorUtils.primarycolor(),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (widget.vehicle.status == "PARKED" ||
                              widget.vehicle.status.toUpperCase() == 'COMPLETED')
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton(
                                onPressed: () async {
                                  final bool isCompleted =
                                      widget.vehicle.status.toUpperCase() == 'COMPLETED';

                                  // For completed bookings, use the stored amount directly
                                  String currentAmount;
                                  if (isCompleted) {
                                    currentAmount = widget.vehicle.totalamout.isNotEmpty
                                        ? widget.vehicle.totalamout
                                        : widget.vehicle.amount;
                                    if (currentAmount.isEmpty) {
                                      currentAmount = await UniversalPrintHelper
                                          .getPrintAmountFromAPI(widget.vehicle.id);
                                    }
                                  } else {
                                    currentAmount = await UniversalPrintHelper
                                        .getPrintAmountFromAPI(widget.vehicle.id);
                                  }

                                  // For completed, show actual parked-in date/time
                                  final String printDate = isCompleted
                                      ? (widget.vehicle.parkeddate.isNotEmpty
                                      ? widget.vehicle.parkeddate
                                      : widget.vehicle.parkingDate)
                                      : widget.vehicle.parkingDate;
                                  final String printTime = isCompleted
                                      ? (widget.vehicle.parkedtime.isNotEmpty
                                      ? widget.vehicle.parkedtime
                                      : widget.vehicle.parkingTime)
                                      : widget.vehicle.parkingTime;

                                  // For completed, calculate duration from parked time to exit time
                                  String? preCalculatedDuration;
                                  if (isCompleted &&
                                      widget.vehicle.parkeddate.isNotEmpty &&
                                      widget.vehicle.parkedtime.isNotEmpty &&
                                      widget.vehicle.exitvehicledate.isNotEmpty &&
                                      widget.vehicle.exitvehicletime.isNotEmpty) {
                                    try {
                                      DateTime? parkedDT, exitDT;
                                      final parkedStr = '${widget.vehicle.parkeddate} ${widget.vehicle.parkedtime}';
                                      final exitStr = '${widget.vehicle.exitvehicledate} ${widget.vehicle.exitvehicletime}';
                                      for (final fmt in ['dd-MM-yyyy hh:mm a', 'dd-MM-yyyy hh:mm:ss a', 'dd-MM-yyyy HH:mm', 'dd-MM-yyyy HH:mm:ss', 'dd-MM-yyyy HH:mm:ss.SSS']) {
                                        try { parkedDT = DateFormat(fmt).parse(parkedStr); break; } catch (_) {}
                                      }
                                      for (final fmt in ['dd-MM-yyyy hh:mm a', 'dd-MM-yyyy hh:mm:ss a', 'dd-MM-yyyy HH:mm', 'dd-MM-yyyy HH:mm:ss', 'dd-MM-yyyy HH:mm:ss.SSS']) {
                                        try { exitDT = DateFormat(fmt).parse(exitStr); break; } catch (_) {}
                                      }
                                      if (parkedDT != null && exitDT != null) {
                                        final dur = exitDT.difference(parkedDT);
                                        if (!dur.isNegative) {
                                          final h = dur.inHours.toString().padLeft(2, '0');
                                          final m = (dur.inMinutes % 60).toString().padLeft(2, '0');
                                          preCalculatedDuration = '$h Hours $m Minutes';
                                        }
                                      }
                                    } catch (_) {}
                                  }

                                  await UniversalPrintHelper.printTicket(
                                    context: context,
                                    vendorName: (widget.vehicle.vendorname.isNotEmpty)
                                        ? widget.vehicle.vendorname
                                        : 'Vendor',
                                    bookingId: widget.vehicle.id,
                                    invoiceId: widget.vehicle.invoiceid,
                                    vehicleType: widget.vehicle.vehicletype,
                                    vehicleNumber: widget.vehicle.vehicleNumber,
                                    parkingDate: printDate,
                                    parkingTime: printTime,
                                    amount: currentAmount,
                                    personName: widget.vehicle.username,
                                    mobileNumber: widget.vehicle.mobilenumber,
                                    vendorId: widget.vehicle.Vendorid,
                                    bookType: widget.vehicle.bookingtype.toString(),
                                    sts: widget.vehicle.sts?.toString(),
                                    preCalculatedDuration: preCalculatedDuration,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: ColorUtils.primarycolor(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  minimumSize: const Size(0, 0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(5),
                                    ),
                                    side: BorderSide(
                                      color: ColorUtils.primarycolor(),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.print,
                                      color: ColorUtils.primarycolor(),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Print',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: ColorUtils.primarycolor(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (widget.vehicle.status == "Approved") ...[
                            SizedBox(
                              height: 35,
                              child: IconButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (BuildContext context) {
                                      return Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              "Reschedule Booking",
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            CusTextField(
                                              labelColor: customTeal,
                                              selectedColor: customTeal,
                                              controller: reschedule,
                                              focusNode: _subscriptionFocusNode,
                                              keyboard: TextInputType.text,
                                              obscure: false,
                                              textInputAction: TextInputAction.done,
                                              inputFormatter: const [],
                                              label: 'Reschedule Parking Date & Time',
                                              hint: selectedDateTime != null
                                                  ? _formatDateTime(selectedDateTime!)
                                                  : (widget.vehicle.parkingDate.isNotEmpty && widget.vehicle.parkingTime.isNotEmpty)
                                                  ? '${widget.vehicle.parkingDate}, ${widget.vehicle.parkingTime}'
                                                  : 'Select Date & Time',
                                              prefixIcon: Padding(
                                                padding: const EdgeInsets.only(left: 10.0, right: 5),
                                                child: Icon(Icons.calendar_today, color: customTeal),
                                              ),
                                              readOnly: true,
                                              onTap: () async {
                                                _showDateTimePickerForSubscription();
                                              },
                                            ),
                                            const SizedBox(height: 20),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                // TextButton(
                                                //   onPressed: () {
                                                //     Navigator.pop(context);
                                                //   },
                                                //   child: Text(
                                                //     "No",
                                                //     style: GoogleFonts.poppins(color: Colors.grey[700]),
                                                //   ),
                                                // ),
                                                const SizedBox(width: 10),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: ColorUtils.primarycolor(),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(5),
                                                    ),
                                                  ),
                                                  onPressed: _isLoading
                                                      ? null
                                                      : () {
                                                    Navigator.pop(context);
                                                    widget.onRefresh();
                                                    _reshedule();
                                                  },
                                                  child: Text(
                                                    "Reschedule",
                                                    style: GoogleFonts.poppins(color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                icon: const Icon(Icons.calendar_month_outlined),
                                iconSize: 19,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(
                              height: 30,
                              child: Center(
                                child: IconButton(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                      ),
                                      builder: (BuildContext context) {
                                        return Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Cancel Booking",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                "Are you sure you want to cancel this booking?",
                                                style: GoogleFonts.poppins(fontSize: 14),
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                    child: Text(
                                                      "No",
                                                      style: GoogleFonts.poppins(color: Colors.grey[700]),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.pop(context);
                                                      try {
                                                        await updateapprovecancel(widget.vehicle.id, 'Cancelled');
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Booking cancelled successfully')),
                                                        );
                                                      } catch (e) {
                                                        print('Cancel error: $e');
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Failed to cancel booking: $e')),
                                                        );
                                                      } finally {
                                                        widget.onRefresh();
                                                      }
                                                    },
                                                    child: Text(
                                                      "Yes, Cancel",
                                                      style: GoogleFonts.poppins(color: Colors.white),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.cancel_outlined),
                                  iconSize: 19,
                                  color: Colors.black,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(
                              left: 12.0,
                              right: 15.0,
                              top: 6.0,
                              bottom: 6.0),
                          decoration: BoxDecoration(
                            color: widget.vehicle.status == 'Cancelled'
                                ? Colors.red
                                : ColorUtils.primarycolor(),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20.0),
                              bottomRight: Radius.circular(20.0),
                            ),
                          ),
                          child: Icon(
                            widget.vehicle.vehicletype == "Car"
                                ? Icons.drive_eta
                                : Icons.directions_bike,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 0),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Parking Schedule: ',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          ' ${widget.vehicle.parkingDate}',
                                          style: GoogleFonts.poppins(fontSize: 12),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          widget.vehicle.parkingTime,
                                          style: GoogleFonts.poppins(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    widget.vehicle.sts == 'Schedule'
                                        ? 'Prescheduled'
                                        : isVendorShortParkingSts(widget.vehicle.sts?.toString())
                                        ? 'Drive-in'
                                        : widget.vehicle.sts,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(height: 10),
                                  if (widget.vehicle.status == "PARKED")
                                    Container(),
                                  const Spacer(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> updateapprovecancel(String bookingId, String newStatus) async {
    final url = Uri.parse('${ApiConfig.baseUrl}vendor/approvedcancelbooking/$bookingId');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print('Booking updated successfully: ${responseBody['data']}');
      } else {
        print('Failed to update booking: ${response.statusCode} ${response.body}');
        try {
          final errorResponse = jsonDecode(response.body);
          throw Exception(errorResponse['message'] ?? 'Failed to update booking status');
        } catch (e) {
          throw Exception('Failed to update booking status: ${response.body}');
        }
      }
    } catch (error) {
      print('Error updating booking status: $error');
      rethrow;
    }
  }
}
