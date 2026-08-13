import 'package:flutter/material.dart';
import 'package:mywheels/config/colorcode.dart';

class nri extends StatefulWidget {
  const nri({super.key});

  @override
  _favouritesState createState() => _favouritesState();
}

class _favouritesState extends State<nri> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colortils.primarycolor(),
      appBar: AppBar(titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('NRI Parking Services',style: TextStyle(color: Colors.black),), // AppBar title

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

