// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global.dart';
import '../model/app_responsive.dart';

import '../orders/database.dart';
import 'display_tracked_order.dart';

class OrderTracker extends StatefulWidget {
  final String orderId;
  const OrderTracker({super.key, required this.orderId});

  @override
  State<OrderTracker> createState() => _OrderTrackerState();
}

class _OrderTrackerState extends State<OrderTracker> {
  Stream? stockStream;

  @override
  void initState() {
    super.initState();
    getontheload();
  }

  Future<void> getOrderId() async {
    final SharedPreferences pref = await SharedPreferences.getInstance();
    var obtainedOrderId = pref.getString('userOrderId');

    if (obtainedOrderId != null) {
      setState(() {
        finalOrderId = obtainedOrderId;
        print(finalOrderId);
      });
    }
  }

  Future<void> getontheload() async {
    stockStream = await DatabaseMethods().getOrder();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppResponsive.isBMobile(context) ? 300 : 400,
      child: StreamBuilder(
        builder: (context, AsyncSnapshot snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return const Text("ConnectionState.none");
            case ConnectionState.waiting:
              return const CircularProgressIndicator();
            case ConnectionState.active:
            case ConnectionState.done:
              List<Widget> contentWidgets = [];
              if (snapshot.hasData) {
                for (DocumentSnapshot ds in snapshot.data.docs) {
                  if (ds["mealNum"] == widget.orderId) {
                    trackerCard(contentWidgets, context, ds);
                  }
                }
              }

              return contentWidgets.isNotEmpty
                  ? ListView(
                      children: contentWidgets,
                    )
                  : const Center(
                      child: Text("You have no order placed",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 25,
                              fontWeight: FontWeight.bold)));
          }
        },
        stream: stockStream,
      ),
    );
  }

  void trackerCard(List<Widget> contentWidgets, BuildContext context,
      DocumentSnapshot<Object?> ds) {
    String deliveredMode = "false";
    String kitchenMode = "false";
    try {
      deliveredMode = ds.get("deliveredMode")?.toString() ?? "";
      kitchenMode = ds.get("kitchenMode")?.toString() ?? "";
    } catch (e) {
      // Handle any errors, such as the field not existing
      print("$e");
    }
    contentWidgets.add(
      SizedBox(
        height: 400,
        child: DisplayTrackedOrder(
          ds: ds,
          kitchenMode: kitchenMode,
          deliveredMode: deliveredMode,
        ),
      ),
    );
  }
}
