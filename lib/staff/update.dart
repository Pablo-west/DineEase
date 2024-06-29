// ignore_for_file: avoid_print, prefer_const_constructors

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../orders/database.dart';

class UpdateOrder extends StatefulWidget {
  final String mealNumber;
  final String foodName;
  final String id;
  final String foodAmount;
  final String paymentOpt;
  final String tableNumber;
  final String userName;
  final String kitchenMode;
  final String deliveredMode;
  const UpdateOrder(
      {super.key,
      required this.mealNumber,
      required this.foodName,
      required this.id,
      required this.foodAmount,
      required this.paymentOpt,
      required this.tableNumber,
      required this.userName,
      required this.kitchenMode,
      required this.deliveredMode});

  @override
  State<UpdateOrder> createState() => _UpdateOrderState();
}

class _UpdateOrderState extends State<UpdateOrder> {
  bool orderMode = true;
  bool kitchenMode = false;
  bool deliveredMode = false;
  @override
  void initState() {
    if (widget.kitchenMode == "true") {
      kitchenMode = true;
    } else {
      kitchenMode = false;
    }
    if (widget.deliveredMode == "true") {
      deliveredMode = true;
    } else {
      deliveredMode = false;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        children: [
          AlertDialog(
            title: Text("Meal  Tracker Update"),
            content: Column(
              children: [
                Text("State the stage of the meal"),
                SizedBox(height: 10),
                listingItems("Meal number: ", widget.foodName),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Order placed"),
                    CupertinoSwitch(
                        dragStartBehavior: DragStartBehavior.start,
                        activeColor: Colors.yellow,
                        value: orderMode,
                        onChanged: (bool s) {
                          setState(() {
                            orderMode = s;
                            // print(orderMode);
                          });
                        }),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Kitchen stage"),
                    CupertinoSwitch(
                        dragStartBehavior: DragStartBehavior.start,
                        activeColor: Colors.red,
                        value: kitchenMode,
                        onChanged: (bool s) {
                          setState(() {
                            kitchenMode = s;
                            // print(kitchenMode);
                          });
                        }),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Delivered stage"),
                    CupertinoSwitch(
                        dragStartBehavior: DragStartBehavior.start,
                        activeColor: Colors.brown,
                        value: deliveredMode,
                        onChanged: (bool s) {
                          setState(() {
                            deliveredMode = s;
                            // print(deliveredMode);
                          });
                        }),
                  ],
                )
              ],
            ),
            actions: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text("Cancel")),
              ElevatedButton(
                  style: ButtonStyle(
                      foregroundColor:
                          WidgetStateProperty.all<Color>(Colors.white),
                      backgroundColor:
                          WidgetStateProperty.all<Color>(Color(0xff131e29))),
                  onPressed: () async {
                    Map<String, dynamic> orderInfoMap = {
                      "timestamp": widget.id,
                      "mealNum": widget.mealNumber,
                      "food": widget.foodName,
                      "foodAmt": "GHS 100.00",
                      "tableNum": widget.tableNumber,
                      "userName": widget.userName,
                      "paymentOption": widget.paymentOpt,
                      "kitchenMode": kitchenMode,
                      "deliveredMode": deliveredMode
                    };
                    DatabaseMethods()
                        .addOrder(orderInfoMap, widget.id)
                        .then((value) {
                      Fluttertoast.showToast(
                          msg:
                              "✔ Successfully updated table: ${widget.tableNumber}",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.CENTER,
                          timeInSecForIosWeb: 3,
                          backgroundColor: Colors.greenAccent,
                          textColor: Colors.white,
                          fontSize: 15.0);
                    });
                    Navigator.of(context).pop(false);
                  },
                  child: Text("Save")),
            ],
          ),
        ],
      ),
    );
  }

  Text listingItems(String title, details) {
    return Text.rich(TextSpan(children: [
      TextSpan(
        text: title,
      ),
      TextSpan(
        text: details,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
      )
    ]));
  }

  Row trackerUpdate(String text, bool trackerMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text),
        CupertinoSwitch(
            dragStartBehavior: DragStartBehavior.start,
            activeColor: Colors.blue,
            value: trackerMode,
            onChanged: (bool s) {
              setState(() {
                trackerMode = s;
                // print(trackerMode);
              });
            }),
      ],
    );
  }
}
