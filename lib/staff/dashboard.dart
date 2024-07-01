import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../model/app_responsive.dart';
import '../orders/database.dart';
import 'update.dart';

class DashboardBody extends StatefulWidget {
  const DashboardBody({super.key});

  @override
  State<DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<DashboardBody> {
  Stream? stockStream;
  String filterMode = "All"; // Default filter mode

  Future<void> getontheload() async {
    stockStream = await DatabaseMethods().getOrder();
    setState(() {});
  }

  @override
  void initState() {
    getontheload();
    super.initState();
  }

  final List<Color> cardColors = [
    Colors.yellow[200]!,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        children: [
          // Dropdown for filtering
          Row(
            children: [
              const Text("Status"),
              const SizedBox(width: 20.0),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: DropdownButton<String>(
                  value: filterMode,
                  onChanged: (String? newValue) {
                    setState(() {
                      filterMode = newValue!;
                    });
                  },
                  items: <String>[
                    'All',
                    'Ordered Mode',
                    'Kitchen Mode',
                    'Delivered Mode'
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder(
              builder: (context, AsyncSnapshot snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                    return const Text("ConnectionState.none");
                  case ConnectionState.waiting:
                    return const CircularProgressIndicator();
                  case ConnectionState.active:
                  case ConnectionState.done:
                    if (snapshot.hasData && snapshot.data.docs.isNotEmpty) {
                      List<DocumentSnapshot> filteredDocs = snapshot.data.docs;

                      // Apply filter based on filterMode
                      filteredDocs = filteredDocs.where((doc) {
                        Color cardColor = getCardColor(doc);
                        if (filterMode == 'Delivered Mode') {
                          return cardColor == Colors.blueGrey[200]!;
                        } else if (filterMode == 'Kitchen Mode') {
                          return cardColor == Colors.red[200]!;
                        } else if (filterMode == 'Ordered Mode') {
                          return cardColor == Colors.yellow[200]!;
                        }
                        return true;
                      }).toList();

                      // Sort filteredDocs by timestamp (String to DateTime)
                      filteredDocs.sort((b, a) {
                        DateTime timestampA = DateTime.parse(a['timestamp']);
                        DateTime timestampB = DateTime.parse(b['timestamp']);
                        return timestampA.compareTo(timestampB);
                      });

                      // Group and display cards by month
                      List<Widget> monthGroups = [];
                      String currentMonth = '';

                      for (int i = 0; i < filteredDocs.length; i++) {
                        DocumentSnapshot ds = filteredDocs[i];
                        DateTime orderDate = DateTime.parse(ds['timestamp']);
                        String month =
                            '${orderDate.month}-${orderDate.year}'; // Format as needed

                        if (month != currentMonth) {
                          // Add heading for new month with a page break
                          monthGroups.add(
                            Center(
                              child: Text(
                                month,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                          currentMonth = month;
                        }

                        // Add card for the current order
                        monthGroups.add(orderPlacedCard(ds, i));
                      }

                      return Container(
                        margin: const EdgeInsets.all(10.0),
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: AppResponsive.isDesktop(context) ||
                                AppResponsive.isTablet(context) ||
                                AppResponsive.isCMobile(context)
                            ? GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      AppResponsive.isDesktop(context) ? 3 : 2,
                                  mainAxisSpacing: 10.0,
                                  crossAxisSpacing: 10.0,
                                  childAspectRatio:
                                      AppResponsive.isDesktop(context) ||
                                              AppResponsive.isTablet(context)
                                          ? 2.4
                                          : 2,
                                ),
                                itemCount: monthGroups.length,
                                itemBuilder: (BuildContext context, int index) {
                                  return monthGroups[index];
                                },
                              )
                            : ListView.builder(
                                itemCount: monthGroups.length,
                                itemBuilder: (context, index) {
                                  return monthGroups[index];
                                },
                              ),
                      );
                    } else {
                      return const Center(
                        child: Text(
                          "No Order(s) made...",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                }
              },
              stream: stockStream,
            ),
          ),
        ],
      ),
    );
  }

  Color getCardColor(DocumentSnapshot<Object?> ds) {
    String deliveredMode = "false";
    String kitchenMode = "false";
    try {
      deliveredMode = ds.get("deliveredMode")?.toString() ?? "";
      kitchenMode = ds.get("kitchenMode")?.toString() ?? "";
    } catch (e) {
      // Handle any errors, such as the field not existing
    }

    // Define the color based on the mode
    if (deliveredMode == "true") {
      return Colors.blueGrey[200]!;
    } else if (kitchenMode == "true") {
      return Colors.red[200]!;
    } else {
      int index = ds.id.hashCode % cardColors.length;
      return cardColors[index];
    }
  }

  Widget orderPlacedCard(DocumentSnapshot<Object?> ds, int index) {
    String id = ds.id.toString();
    String tableNumber = ds["tableNum"].toString();
    String userName = ds["userName"].toString();
    String food = ds["food"].toString();
    String mealNumber = ds["mealNum"].toString();
    String foodAmount = ds["foodAmt"].toString();
    String paymentOpt = ds["paymentOption"].toString();
    String timestamp = ds["timestamp"].toString();
    String deliveredMode = "false";
    String kitchenMode = "false";
    try {
      deliveredMode = ds.get("deliveredMode")?.toString() ?? "";
      kitchenMode = ds.get("kitchenMode")?.toString() ?? "";
    } catch (e) {
      // Handle any errors, such as the field not existing
    }

    // Get the card color using the getCardColor function
    Color cardColor = getCardColor(ds);

    return SingleChildScrollView(
      child: Card(
        color: cardColor,
        child: Container(
          padding: const EdgeInsets.all(10),
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
                  listingItems("Time stamp: ", timestamp),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                // crossAxisAlignment: CrossAxisAlignment.end,
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
                        },
                      );
                    },
                    child: const Icon(Icons.more_vert_rounded),
                  ),
                  Column(
                    children: [
                      const Card(
                        child: SizedBox(
                          child: Padding(
                            padding: EdgeInsets.all(5.0),
                            child: Icon(Icons.restaurant_menu_outlined,
                                color: Colors.amber),
                          ),
                        ),
                      ),
                      Card(
                        child: SizedBox(
                          child: kitchenMode == "true"
                              ? const Padding(
                                  padding: EdgeInsets.all(5.0),
                                  child: Icon(Icons.restaurant_menu_outlined,
                                      color: Colors.red),
                                )
                              : Container(),
                        ),
                      ),
                      Card(
                        child: SizedBox(
                          child: deliveredMode == "true"
                              ? const Padding(
                                  padding: EdgeInsets.all(5.0),
                                  child: Icon(Icons.restaurant_menu_outlined,
                                      color: Colors.blueGrey),
                                )
                              : Container(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Text listingItems(String title, details) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: title),
          TextSpan(
            text: details,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
          ),
        ],
      ),
    );
  }
}
