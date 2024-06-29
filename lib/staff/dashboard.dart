// ignore_for_file: prefer_const_constructors, avoid_print, prefer_const_literals_to_create_immutables

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../global.dart';
import '../model/app_responsive.dart';
import '../orders/database.dart';
import 'update.dart';

class DashboardBody extends StatefulWidget {
  const DashboardBody({super.key});

  @override
  State<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<DashboardBody> {
  // Stream? stockStream;
  Future<void> getontheload() async {
    stockStream = await DatabaseMethods().getOrder();
    setState(() {});
  }

  @override
  void initState() {
    getontheload();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      builder: (context, AsyncSnapshot snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            // Handle ConnectionState.none
            return Text("ConnectionState.none");
          case ConnectionState.waiting:
            // Handle ConnectionState.waiting
            return CircularProgressIndicator();
          case ConnectionState.active:
          case ConnectionState.done:
            if (snapshot.hasData && snapshot.data.docs.isNotEmpty) {
              return Container(
                  margin: const EdgeInsets.all(10.0),
                  child: AppResponsive.isDesktop(context) ||
                          AppResponsive.isTablet(context) ||
                          AppResponsive.isCMobile(context)
                      ? GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: AppResponsive.isDesktop(context)
                                ? 3
                                : 2, // Number of columns
                            mainAxisSpacing: 10.0, // Spacing between rows
                            crossAxisSpacing: 10.0, // Spacing between columns
                            childAspectRatio:
                                AppResponsive.isDesktop(context) ||
                                        AppResponsive.isTablet(context)
                                    ? 2.4
                                    : 2, // Aspect ratio of grid items
                          ),
                          itemCount: snapshot.data.docs.length,
                          itemBuilder: (BuildContext context, int index) {
                            DocumentSnapshot ds = snapshot.data.docs[index];
                            return orderPlacedCard(ds);
                          },
                        )
                      : ListView.builder(
                          itemCount: snapshot.data.docs.length,
                          itemBuilder: (context, index) {
                            DocumentSnapshot ds = snapshot.data.docs[index];
                            return orderPlacedCard(ds);
                          }));
            } else {
              return Center(
                  child: Text("No Order(s) made...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 25,
                          fontWeight: FontWeight.bold)));
            }
        }
      },
      stream: stockStream,
    );
  }

  Card orderPlacedCard(DocumentSnapshot<Object?> ds) {
    String id = ds.id.toString();
    String tableNumber = ds["tableNum"].toString();
    String userName = ds["userName"].toString();
    String food = ds["food"].toString();
    String mealNumber = ds["mealNum"].toString();
    String foodAmount = ds["foodAmt"].toString();
    String paymentOpt = ds["paymentOption"].toString();
    String deliveredMode = "false";
    String kitchenMode = "false";
    try {
      deliveredMode = ds.get("deliveredMode")?.toString() ?? "";
      kitchenMode = ds.get("kitchenMode")?.toString() ?? "";
    } catch (e) {
      // Handle any errors, such as the field not existing
      // print("$e");
    }

    return Card(
      child: Container(
        // margin: EdgeInsets.only(left: 20),
        padding: EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                listingItems("Table number: ", tableNumber),
                listingItems("Meal number: ", mealNumber),
                listingItems("Meal name: ", food),
                listingItems("Name: ", userName),
                listingItems("Amount: ", foodAmount),
                listingItems("Mode of payment: ", paymentOpt),
              ],
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return UpdateOrder(
                            mealNumber: mealNumber,
                            foodName: food,
                            id: id,
                            foodAmount: foodAmount,
                            paymentOpt: paymentOpt,
                            tableNumber: tableNumber,
                            userName: userName,
                            kitchenMode: kitchenMode,
                            deliveredMode: deliveredMode,
                          );
                        });
                  },
                  child: Icon(Icons.more_vert_rounded),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      child: Icon(Icons.restaurant_menu_outlined,
                          color: Colors.amberAccent),
                    ),
                    SizedBox(
                        child: kitchenMode == "true"
                            ? Icon(Icons.restaurant_menu_outlined,
                                color: Colors.red)
                            : Container()),
                    SizedBox(
                        child: deliveredMode == "true"
                            ? Icon(Icons.restaurant_menu_outlined,
                                color: Colors.brown)
                            : Container())
                  ],
                ),
              ],
            )
          ],
        ),
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
}
