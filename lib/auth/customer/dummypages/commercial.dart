import 'package:flutter/material.dart';
import 'package:mywheels/config/colorcode.dart';

class commercial extends StatefulWidget {
  const commercial({super.key});

  @override
  _favouritesState createState() => _favouritesState();
}

class _favouritesState extends State<commercial> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colortils.primarycolor(),
      appBar: AppBar(titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Corporate Solution',style: TextStyle(color: Colors.black),), // AppBar title

      ),
      body: Column(
        children: [


          Container(
            child: Image.asset("assets/coming.png"),
          ),

        ],
      ),
    );
  }
}

