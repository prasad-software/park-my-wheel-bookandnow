import 'package:flutter/material.dart';

class LoadingGif extends StatelessWidget {
  const LoadingGif({
    super.key,
    this.padding = 80.0,
    this.gifPath = 'assets/gifload.gif',
  });

  final double padding;
  final String gifPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Image.asset(gifPath),
        ),
      ),
    );
  }

}
