// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Stream? stockStream;

String trakerStage = "";
String? finalOrderId;
String waiterUsername = "Paa";
String? finalOrderId1;
String? finalOrderId2;
String? finalOrderId3;
String? finalOrderId4;
String? finalOrderId5;
String? userName;
bool loggedIn = true;
String? foodTitle;
dynamic obtainedOrderId;
dynamic obtainedOrderId1;
dynamic obtainedOrderId2;
dynamic obtainedOrderId3;
dynamic obtainedOrderId4;
dynamic obtainedOrderId5;

int duration = 60;
int timerCount = 10;
String? deliveryTimer;

const String kPassNullError = "Enter your password";

Future<dynamic> unfilledField(context) {
  return showDialog(
    // barrierDismissible: false,
    context: context,
    builder: (BuildContext context) {
      return const AlertDialog(
        icon: Center(
          child: FaIcon(FontAwesomeIcons.triangleExclamation,
              size: 50, color: Colors.redAccent),
        ),
        content: Text(
          "You left out some required field(s).",
          textAlign: TextAlign.center,
        ),
      );
    },
  );
}
