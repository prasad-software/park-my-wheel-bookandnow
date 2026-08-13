import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mywheels/config/colorcode.dart';
import 'package:mywheels/pageloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fast_contacts/fast_contacts.dart';

import '../../vendor/vendorcustomfield.dart';

class SearchfiendScreen extends StatefulWidget {
  const SearchfiendScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchfiendScreen> {
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;
  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];

  @override
  void initState() {
    super.initState();
    getContactPermission();
    searchController.addListener(_filterContacts);
  }

  void getContactPermission() async {
    if (await Permission.contacts.isGranted) {
      fetchContacts();
    } else {
      final status = await Permission.contacts.request();
      if (status.isGranted) {
        fetchContacts();
      }
    }
  }

  void fetchContacts() async {
    try {
      final allContacts = await FastContacts.getAllContacts();
      contacts = allContacts.where((contact) {
        return contact.displayName.isNotEmpty && contact.phones.isNotEmpty;
      }).toList();

      setState(() {
        filteredContacts = contacts;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _filterContacts() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      filteredContacts = contacts.where((contact) {
        final nameMatch = contact.displayName.toLowerCase().contains(query);
        final phoneMatch = contact.phones.any((phone) =>
            phone.number.replaceAll(RegExp(r'\D+'), '').contains(query));
        return nameMatch || phoneMatch;
      }).toList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const LoadingGif() // Show loading GIF before the Scaffold
        :Scaffold(
      // backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          'Search Contacts',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            // fontWeight: FontWeight.w600,
          ),
        ),
        // backgroundColor: ColorUtils.primarycolor(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
          children: [
            // const SizedBox(height: 18),
            CustommTextField(
              keyboard: TextInputType.text,
              controller: searchController,
              focusNode: FocusNode(),
              textInputAction: TextInputAction.search,
              label: 'Search',
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredContacts.isEmpty
                  ? Center(
                child: Text(
                  'No contacts found',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              )
                  :ListView.builder(
                itemCount: filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = filteredContacts[index];
                  final phoneNumber = contact.phones.isNotEmpty
                      ? contact.phones.first.number
                      : "No phone number";

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey, width: 0.5),
                    ),
                    margin: const EdgeInsets.only(bottom: 2),
                    child: ListTile(
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      minLeadingWidth: 0,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: ColorUtils.primarycolor(),
                        child: Text(
                          contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : "?",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      title: Text(
                        contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        phoneNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      onTap: () async {
                        final Uri smsUrl = Uri.parse("sms:$phoneNumber");
                        if (await canLaunchUrl(smsUrl)) {
                          await launchUrl(smsUrl);
                        }
                      },
                    ),
                  );


                },
              ),

            ),
          ],
        ),
      ),),
    );
  }
}