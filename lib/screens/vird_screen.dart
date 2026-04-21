import 'package:flutter/material.dart';

class VirdScreen extends StatelessWidget {
  const VirdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/vird_logo.png',
        width: MediaQuery.of(context).size.width / 2,
      ),
    );
  }
}
