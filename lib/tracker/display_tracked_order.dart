// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors, avoid_print

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global.dart';
import '../model/app_responsive.dart';

class DisplayTrackedOrder extends StatefulWidget {
  final dynamic ds;
  final String kitchenMode;
  final String deliveredMode;

  const DisplayTrackedOrder(
      {super.key,
      required this.ds,
      required this.kitchenMode,
      required this.deliveredMode});

  @override
  State<DisplayTrackedOrder> createState() => _DisplayTrackedOrderState();
}

class _DisplayTrackedOrderState extends State<DisplayTrackedOrder> {
  bool orderMode = true;
  bool kitchenMode = false;
  bool deliveredMode = false;
  String trakerStage = "";

  Future<void> getOrderId() async {
    await Future.delayed(Duration(seconds: duration));

    final SharedPreferences pref = await SharedPreferences.getInstance();

    if (widget.ds["mealNum"] == finalOrderId) {
      pref.remove('userOrderId');
      finalOrderId = null;
    } else if (widget.ds["mealNum"] == finalOrderId1) {
      pref.remove('userOrderId1');
      finalOrderId1 = null;
    } else if (widget.ds["mealNum"] == finalOrderId2) {
      pref.remove('userOrderId2');
      finalOrderId2 = null;
    } else if (widget.ds["mealNum"] == finalOrderId3) {
      pref.remove('userOrderId3');
      finalOrderId3 = null;
    } else if (widget.ds["mealNum"] == finalOrderId4) {
      pref.remove('userOrderId4');
      finalOrderId4 = null;
    }
  }

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
    //renders the stages of the order to the mealStage string
    if (deliveredMode == true) {
      String mealStage = "Delivered Stage";
      getOrderId();
      trakerStage = mealStage;
    } else if (kitchenMode == true) {
      String mealStage = "Kitchen Stage";
      trakerStage = mealStage;
    } else {
      String mealStage = "Ordered Stage";
      trakerStage = mealStage;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      // mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: Container()),

            Expanded(
              flex: 5,
              child: Text(
                "Track your meal",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Expanded(flex: 1, child: Container()),
            //close button
            IconButton(
                padding: EdgeInsets.only(right: 10),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: Icon(Icons.close_outlined))
          ],
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // clipBehavior: Clip.none,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        onProcessState("Ordered"),
                        SizedBox(
                            child: kitchenMode
                                ? onProcessState("Kitchen")
                                : offProcessState("Kitchen")),
                        SizedBox(
                            child: deliveredMode
                                ? Text("Delivered",
                                    style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize:
                                            AppResponsive.isBMobile(context)
                                                ? 15.5
                                                : 11))
                                : Text("Delivered",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w600,
                                        fontSize:
                                            AppResponsive.isBMobile(context)
                                                ? 15.5
                                                : 11))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Client order details
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Text("Order Placed Details",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      )),
                  SizedBox(height: 10),
                  AppResponsive.isBMobile(context)
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                              orderPlaceDetailsOne(widget.ds),
                              orderPlaceDetailsTwo(widget.ds),
                            ])
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              orderPlaceDetailsOne(widget.ds),
                              orderPlaceDetailsTwo(widget.ds),
                            ]),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: Card(
            child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: AppResponsive.isBMobile(context)
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          listingItems("Your meal is at: ", trakerStage),
                          listingItems("Your waiter for today is: ", "Paa"),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          listingItems("Your meal is at: ", trakerStage),
                          listingItems("Your waiter for today is: ", "Paa"),
                        ],
                      )),
          ),
        ),
      ],
    );
  }

  Column orderPlaceDetailsTwo(var ds) {
    String mealNumber = ds["mealNum"].toString();
    String foodAmount = ds["foodAmt"].toString();
    String paymentOpt = ds["paymentOption"].toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        listingItems("Meal number: ", mealNumber),
        listingItems("Amount: ", foodAmount),
        listingItems("Mode of payment: ", paymentOpt),
      ],
    );
  }

  Column orderPlaceDetailsOne(ds) {
    String tableNumber = ds["tableNum"].toString();
    String userName = ds["userName"].toString();
    String food = ds["food"].toString();
    setState(() {
      foodTitle = food;
      // print(foodTitle);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        listingItems("Table number: ", tableNumber),
        listingItems("Name: ", userName),
        listingItems("Meal name: ", food),
      ],
    );
  }

  Widget offProcessState(String processName) {
    return Row(
      children: [
        Text(processName,
            style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: AppResponsive.isBMobile(context) ? 15.5 : 11)),
        offProgress(),
      ],
    );
  }

  Widget onProcessState(String processName) {
    return Row(
      children: [
        Text(processName,
            style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.w600,
                fontSize: AppResponsive.isBMobile(context) ? 15.5 : 10)),
        onProgress()
      ],
    );
  }

  Widget offProgress() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.isBMobile(context) ? 10.0 : 5),
      child: AppResponsive.isBMobile(context)
          ? Text("- - - -",
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: AppResponsive.isBMobile(context) ? 20.5 : 11))
          : Text(">",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }

  Widget onProgress() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppResponsive.isBMobile(context) ? 10.0 : 5),
      child: AppResponsive.isBMobile(context)
          ? Text("- - - -",
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: AppResponsive.isBMobile(context) ? 20.5 : 11))
          : Text(">",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
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
}
