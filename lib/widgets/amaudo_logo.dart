import 'package:flutter/material.dart';

class AmaudoLogo extends StatelessWidget {
  final double size;

  const AmaudoLogo({
    super.key,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/amaudo_logo.png',
      width: size,
      fit: BoxFit.contain,
    );
  }
}