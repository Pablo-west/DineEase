// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';

class AppResponsive extends StatelessWidget {
  final Widget mobile;
  final Widget cmobile;
  final Widget nmobile;
  final Widget amobile;
  final Widget bmobile;
  final Widget tablet;
  final Widget desktop;

  const AppResponsive(
      {Key? key,
      required this.mobile,
      required this.tablet,
      required this.desktop,
      required this.nmobile,
      required this.amobile,
      required this.bmobile,
      required this.cmobile})
      : super(key: key);

  /// This size work for my design, maybe you need some changes depend on your design
  /// make function that can help us later
  // static bool isNMobile(context) => MediaQuery.of(context).size.width < 330;
  static bool isAMobile(context) => MediaQuery.of(context).size.width < 330;
  static bool isBMobile(context) => MediaQuery.of(context).size.width > 600;
  static bool isCMobile(context) => MediaQuery.of(context).size.width > 750;
  static bool isMobile(context) => MediaQuery.of(context).size.width < 990;
  static bool isTablet(context) =>
      MediaQuery.of(context).size.width < 1250 &&
      MediaQuery.of(context).size.width >= 990;
  static bool isDesktop(context) => MediaQuery.of(context).size.width >= 1250;

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return desktop;
    } else if (isTablet(context)) {
      return tablet;
    } else if (isMobile(context)) {
      return mobile;
    } else if (isAMobile(context)) {
      return amobile;
    } else if (isBMobile(context)) {
      return bmobile;
    } else if (isCMobile(context)) {
      return cmobile;
    } else {
      return nmobile;
    }
  }
}
