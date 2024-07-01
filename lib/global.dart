// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

void storeOrderId(String mealNum) async {
  final SharedPreferences perf = await SharedPreferences.getInstance();

  if (obtainedOrderId == null) {
    // finalOrderId = mealNum;
    obtainedOrderId = perf.setString('userOrderId', mealNum);
    // print("0a: ${obtainedOrderId.toString()}");

    // print(0);
  } else if (obtainedOrderId1 == null) {
    String mealNum1 = mealNum;
    obtainedOrderId1 = perf.setString('userOrderId1', mealNum1);
    // print("1b: ${obtainedOrderId1.toString()}");

    // print(1);
  } else if (obtainedOrderId2 == null) {
    String mealNum2 = mealNum;
    obtainedOrderId2 = perf.setString('userOrderId2', mealNum2);
    // print("2b: ${obtainedOrderId2.toString()}");

    // print(2);
  } else if (obtainedOrderId3 == null) {
    String mealNum3 = mealNum;

    obtainedOrderId3 = perf.setString('userOrderId3', mealNum3);
    // print("3b: ${obtainedOrderId3.toString()}");

    // print(3);
  } else if (obtainedOrderId4 == null) {
    String mealNum4 = mealNum;

    obtainedOrderId4 = perf.setString('userOrderId4', mealNum4);
    // print("4b: ${obtainedOrderId4.toString()}");

    // print(4);
  } else {
    String mealNum5 = mealNum;

    // print(5);
    obtainedOrderId5 = perf.setString('userOrderId5', mealNum5);
    // print("5b: ${obtainedOrderId5.toString()}");
  }
}

void incrementCounter(String mealNum) {
  // setState(() {
  if (obtainedOrderId == null) {
    finalOrderId = mealNum;
  } else if (obtainedOrderId1 == null) {
    finalOrderId1 = mealNum;
  } else if (obtainedOrderId2 == null) {
    finalOrderId2 = mealNum;
  } else if (obtainedOrderId3 == null) {
    finalOrderId3 = mealNum;
  } else if (obtainedOrderId4 == null) {
    finalOrderId4 = mealNum;
  } else {
    finalOrderId5 = mealNum;
  }
  // setState(() {
  finalOrderId;
  finalOrderId1;
  finalOrderId2;
  finalOrderId3;
  finalOrderId4;
  // });
  // });
}
