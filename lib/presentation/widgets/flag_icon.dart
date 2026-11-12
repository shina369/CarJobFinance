// National flag drawn as an image. Flag emoji are not rendered on Windows
// (they show up as two letters), so the app uses bundled SVG flags instead.
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

class FlagIcon extends StatelessWidget {
  const FlagIcon(this.countryCode, {super.key, this.width = 28});

  /// ISO 3166-1 alpha-2 country code (e.g. 'BR').
  final String countryCode;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 2 / 3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CountryFlag.fromCountryCode(
        countryCode,
        theme: ImageTheme(width: width, height: height),
      ),
    );
  }
}
