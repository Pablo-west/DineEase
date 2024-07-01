import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../global.dart';
import '../model/theme_helper.dart';
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

  const UpdateOrder({
    super.key,
    required this.mealNumber,
    required this.foodName,
    required this.id,
    required this.foodAmount,
    required this.paymentOpt,
    required this.tableNumber,
    required this.userName,
    required this.kitchenMode,
    required this.deliveredMode,
  });

  @override
  State<UpdateOrder> createState() => _UpdateOrderState();
}

class _UpdateOrderState extends State<UpdateOrder> {
  final TextEditingController waiterNameController = TextEditingController();

  bool orderMode = true;
  bool kitchenMode = false;
  bool deliveredMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.kitchenMode == "true") {
      kitchenMode = true;
    }
    if (widget.deliveredMode == "true") {
      deliveredMode = true;
    }
    waiterNameController.text = waiterUsername;
  }

  @override
  void dispose() {
    waiterNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500,
      child: AlertDialog(
        title: const Text("Meal Tracker Update"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("State the stage of the meal"),
            const SizedBox(height: 10),
            listingItems("Meal number: ", widget.foodName),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Order placed"),
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
                const Text("Kitchen stage"),
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
                const Text("Delivered stage"),
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
            ),
            const SizedBox(height: 5),
            waiterName(waiterNameController),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              saveOrderInfo();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Text listingItems(String title, String details) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: title,
          ),
          TextSpan(
            text: details,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
          )
        ],
      ),
    );
  }

  Widget waiterName(TextEditingController controller) {
    return TextFormField(
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.text,
      controller: controller,
      decoration: ThemeHelper().textInputDecoration(
        "Enter Waiter Name*",
        "Enter Waiter Name*",
        "Waiter Name",
        null,
      ),
      validator: (value) {
        if (value!.isEmpty) {
          return "Waiter name cannot be empty";
        }
        return null;
      },
    );
  }

  void saveOrderInfo() {
    Map<String, dynamic> orderInfoMap = {
      "timestamp": widget.id,
      "mealNum": widget.mealNumber,
      "food": widget.foodName,
      "foodAmt": "GHS 100.00", // Replace with actual food amount logic
      "tableNum": widget.tableNumber,
      "userName": widget.userName,
      "paymentOption": widget.paymentOpt,
      "kitchenMode": kitchenMode.toString(), // Convert bool to String
      "deliveredMode": deliveredMode.toString(), // Convert bool to String
    };

    DatabaseMethods().addOrder(orderInfoMap, widget.id).then((value) {
      Fluttertoast.showToast(
        msg: "✔ Successfully updated table: ${widget.tableNumber}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 3,
        backgroundColor: Colors.greenAccent,
        textColor: Colors.white,
        fontSize: 15.0,
      );
      Navigator.of(context).pop();
    }).catchError((error) {
      Fluttertoast.showToast(
        msg: "Error updating order: $error",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 3,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
        fontSize: 15.0,
      );
    });
  }
}
