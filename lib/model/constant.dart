import 'package:flutter/material.dart';

const String kNullValue = "Please fill out this field";
List<dynamic> paymentOptArray = <String>[
  "Cash",
  "G-money",
  "Google Pay",
  "MTN Momo",
  "Telecel cash",
  // "Altar Servers"
];

class MenuListStyle {
  static const TextStyle menuName = TextStyle(
    color: Color(0xFFFFFFFF),
    fontWeight: FontWeight.w600,
    fontSize: 20,
  );
  static const TextStyle menuDetails =
      TextStyle(color: Color(0xFFFFFFFF), fontSize: 15);
}
