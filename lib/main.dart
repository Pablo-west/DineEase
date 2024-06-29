// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_print, unnecessary_import, sort_child_properties_last, unnecessary_null_comparison

import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_speed_dial/simple_speed_dial.dart';

import 'global.dart';

import 'menu list/menu_list.dart';
import 'model/app_responsive.dart';
import 'model/theme_helper.dart';
import 'popular dish/popular_dish.dart';
import 'staff/staff_dashboard_main.dart';
import 'tracker/track_order.dart';
// import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: const FirebaseOptions(
            apiKey: "AIzaSyBKC3GD_3Bcdf7u7lrHVffyMaqVDJ-Mr-o",
            appId: "1:328696000707:web:6fbd18df36b31ca219f276",
            messagingSenderId: "G-FKD3GQ32BS",
            projectId: "dineease-f81e5"));
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DineEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });

  // final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  final ScrollController controller = ScrollController();

  final loginButton = FocusNode();
  final TextEditingController setPassword = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool obscurePassword = true;
  String settingsPin = "1215";

  Future<void> getOrderId() async {
    final SharedPreferences pref = await SharedPreferences.getInstance();
    pref.clear();

    obtainedOrderId = pref.getString('userOrderId');
    obtainedOrderId1 = pref.getString('userOrderId1');
    obtainedOrderId2 = pref.getString('userOrderId2');
    obtainedOrderId3 = pref.getString('userOrderId3');
    obtainedOrderId4 = pref.getString('userOrderId4');
    obtainedOrderId5 = pref.getString('userOrderId5');

    if (obtainedOrderId != null) {
      setState(() {
        finalOrderId = obtainedOrderId.toString();
        print("0:$finalOrderId");
      });
    }
    if (obtainedOrderId1 != null) {
      setState(() {
        finalOrderId1 = obtainedOrderId1.toString();
        print("1:$finalOrderId1");
      });
    }
    if (obtainedOrderId2 != null) {
      setState(() {
        finalOrderId2 = obtainedOrderId2.toString();
        print("2: $finalOrderId2");
      });
    }
    if (obtainedOrderId3 != null) {
      setState(() {
        finalOrderId3 = obtainedOrderId3.toString();
        print("3:$finalOrderId3");
      });
    }
    if (obtainedOrderId4 != null) {
      setState(() {
        finalOrderId4 = obtainedOrderId4.toString();
        print("4: $finalOrderId4");
      });
    }
    if (obtainedOrderId5 != null) {
      setState(() {
        finalOrderId5 = obtainedOrderId5.toString();
        print("5: $finalOrderId5");
      });
    }
  }

  @override
  void initState() {
    getOrderId();
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    super.initState();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          finalOrderId;
          finalOrderId1;
          finalOrderId2;
          finalOrderId3;
          finalOrderId4;
        });
        if (!animationController.isDismissed) {
          animationController.reverse();
        }
      },
      child: Scaffold(
        //a floating button activated when order is made
        floatingActionButton: Builder(builder: (context) {
          return Builder(builder: (context) {
            return SpeedDial(
              controller: animationController,
              openBackgroundColor: Colors.white,
              child: Icon(Icons.shopping_cart),
              closedForegroundColor: Colors.white,
              openForegroundColor: Colors.black,
              closedBackgroundColor: Colors.black,
              speedDialChildren: [
                speedDialFoodList4(context, finalOrderId4.toString()),
                speedDialFoodList3(context, finalOrderId3.toString()),
                speedDialFoodList2(context, finalOrderId2.toString()),
                speedDialFoodList1(context, finalOrderId1.toString()),
                speedDialFoodList(context, finalOrderId.toString()),
              ],
            );
          });
        }),
        body: Theme(
          data: Theme.of(context).copyWith(
            scrollbarTheme: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all(Colors.black54),
                crossAxisMargin: 5),
          ),
          child: Scrollbar(
            controller: controller,
            thumbVisibility: true,
            trackVisibility: true,
            child: ListView(
              controller: controller,
              scrollDirection: Axis.vertical,
              children: [
                //Header banner & logo
                Container(
                  width: mediaQueryData.size.width,
                  clipBehavior: Clip.none,
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 20,
                    child: Image.asset(
                      'assets/banners/banner3.png',
                      scale: 3,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 30),

                //About section
                Center(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                      text: "How it ",
                      style: TextStyle(fontSize: 18),
                    ),
                    TextSpan(
                      text: "Works?",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    )
                  ])),
                ),
                SizedBox(height: 20),
                Container(
                  margin: EdgeInsets.only(
                      left: AppResponsive.isTablet(context) ||
                              AppResponsive.isDesktop(context)
                          ? 30
                          : 20,
                      right: AppResponsive.isTablet(context) ||
                              AppResponsive.isDesktop(context)
                          ? 30
                          : 20),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        stepsWorks(Icon(Icons.qr_code_2_outlined, size: 50),
                            "Scan QR code or Tap the NFC tag\nto access today's menu"),
                        SizedBox(
                            width: AppResponsive.isTablet(context) ||
                                    AppResponsive.isDesktop(context)
                                ? 45
                                : 15),
                        stepsWorks(Icon(Icons.menu_book_outlined, size: 50),
                            "Pick your tasty meal\nand place your order"),
                        SizedBox(
                            width: AppResponsive.isTablet(context) ||
                                    AppResponsive.isDesktop(context)
                                ? 45
                                : 5),
                        stepsWorks(Icon(Icons.spoke_outlined, size: 50),
                            "Enjoy Our Tasty\nOrganic Food!"),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 50),

                //Displaying of popular dishes
                Center(
                  child: Text(
                    "Our Popular Dishes",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 25,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Divider(
                  indent: 100,
                  endIndent: 100,
                  thickness: 3,
                ),
                SizedBox(height: AppResponsive.isMobile(context) ? 5 : 10),
                PopularDish(),
                SizedBox(height: AppResponsive.isMobile(context) ? 5 : 10),
                Divider(
                  indent: 100,
                  endIndent: 100,
                  thickness: 3,
                ),
                SizedBox(height: AppResponsive.isMobile(context) ? 30 : 50),

                // Listing menu
                Center(
                  child: Text(
                    "Our Menu List",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 25,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  // padding: EdgeInsets.all(10),
                  margin: EdgeInsets.symmetric(
                      horizontal: AppResponsive.isTablet(context) ||
                              AppResponsive.isDesktop(context)
                          ? 200
                          : 20),
                  height: AppResponsive.isTablet(context) ||
                          AppResponsive.isDesktop(context) ||
                          AppResponsive.isBMobile(context)
                      ? mediaQueryData.size.height
                      : mediaQueryData.size.height / 1.3,
                  width: 10,
                  child: Card(
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 5),
                        child: MenuList(mediaQueryData: mediaQueryData),
                      )),
                ),
                SizedBox(height: 50),
                Divider(thickness: 3, color: Colors.brown),

                //Footer section [ pages nagivation, contact details & location ]
                SizedBox(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        child: AppResponsive.isTablet(context) ||
                                AppResponsive.isDesktop(context) ||
                                AppResponsive.isBMobile(context)
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  contactUs(),
                                  openHours(),
                                  quickLinks(),
                                ],
                              )
                            : Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 20),
                                child: Column(
                                  children: [
                                    contactUs(),
                                    openHours(),
                                    quickLinks(),
                                  ],
                                ),
                              )),
                    SizedBox(
                        height: AppResponsive.isTablet(context) ||
                                AppResponsive.isDesktop(context) ||
                                AppResponsive.isBMobile(context)
                            ? 30
                            : 0)
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SpeedDialChild speedDialFoodList(BuildContext context, orderId) {
    return SpeedDialChild(
      child: Icon(Icons.restaurant_menu_outlined),
      foregroundColor: Colors.white,
      backgroundColor: Colors.red,
      label: finalOrderId != null ? orderId : " No Order Listed",
      onPressed: () {
        updateOrders(orderId);
        animationController.reverse();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Container(
                  height: finalOrderId == null ? 200 : null,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.only(top: 16),
                  child: finalOrderId != null
                      ? OrderTracker(
                          orderId: orderId,
                        )
                      : nullTextStyle()),
            );
          },
        );
      },
      // closeSpeedDialOnPressed: false,
    );
  }

  SpeedDialChild speedDialFoodList1(BuildContext context, orderId) {
    return SpeedDialChild(
      child: Icon(Icons.restaurant_menu_outlined),
      foregroundColor: Colors.white,
      backgroundColor: Colors.red,
      label: finalOrderId1 != null ? orderId : " No Order Listed",
      onPressed: () {
        updateOrders(orderId);
        print(orderId);
        animationController.reverse();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Container(
                  height: finalOrderId1 == null ? 200 : null,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.only(top: 16),
                  child: finalOrderId1 != null
                      ? OrderTracker(
                          orderId: orderId,
                        )
                      : nullTextStyle()),
            );
          },
        );
      },
      // closeSpeedDialOnPressed: false,
    );
  }

  SpeedDialChild speedDialFoodList2(BuildContext context, orderId) {
    return SpeedDialChild(
      child: Icon(Icons.restaurant_menu_outlined),
      foregroundColor: Colors.white,
      backgroundColor: Colors.red,
      label: finalOrderId2 != null ? orderId : " No Order Listed",
      onPressed: () {
        updateOrders(orderId);

        animationController.reverse();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Container(
                  height: finalOrderId2 == null ? 200 : null,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.only(top: 16),
                  child: finalOrderId2 != null
                      ? OrderTracker(
                          orderId: orderId,
                        )
                      : nullTextStyle()),
            );
          },
        );
      },
      // closeSpeedDialOnPressed: false,
    );
  }

  SpeedDialChild speedDialFoodList3(BuildContext context, orderId) {
    return SpeedDialChild(
      child: Icon(Icons.restaurant_menu_outlined),
      foregroundColor: Colors.white,
      backgroundColor: Colors.red,
      label: finalOrderId3 != null ? orderId : " No Order Listed",
      onPressed: () {
        updateOrders(orderId);

        animationController.reverse();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Container(
                  height: finalOrderId3 == null ? 200 : null,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.only(top: 16),
                  child: finalOrderId3 != null
                      ? OrderTracker(
                          orderId: orderId,
                        )
                      : nullTextStyle()),
            );
          },
        );
      },
      // closeSpeedDialOnPressed: false,
    );
  }

  SpeedDialChild speedDialFoodList4(BuildContext context, orderId) {
    return SpeedDialChild(
      child: Icon(Icons.restaurant_menu_outlined),
      foregroundColor: Colors.white,
      backgroundColor: Colors.red,
      label: finalOrderId4 != null ? orderId : " No Order Listed",
      onPressed: () {
        updateOrders(orderId);

        animationController.reverse();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Container(
                  height: finalOrderId4 == null ? 200 : null,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.only(top: 16),
                  child: finalOrderId4 != null
                      ? OrderTracker(
                          orderId: orderId,
                        )
                      : nullTextStyle()),
            );
          },
        );
      },
      // closeSpeedDialOnPressed: false,
    );
  }

  Center nullTextStyle() {
    return Center(
        child: Text("No Order Listed",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 25,
                fontWeight: FontWeight.bold)));
  }

  Widget quickLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        footerHeadTitle("Quick Link"),
        GestureDetector(
            onTap: () {
              print("Todays Menu");
            },
            child: contactListItem(Icon(Icons.smart_button), "Todays Menu")),
        GestureDetector(
            onTap: () {
              settingPin(context);
            },
            child: contactListItem(Icon(Icons.smart_button), "Staff")),
        GestureDetector(
            onTap: () {
              settingPin(context);
            },
            child: contactListItem(Icon(Icons.smart_button), "Dashboard")),
      ],
    );
  }

  Future<dynamic> settingPin(BuildContext context) {
    return showDialog(
        context: context,
        builder: (context) {
          return Builder(builder: (context) {
            return AlertDialog(
              title: Text('Admin Page'),
              content: SizedBox(
                width: 200,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                          "You are trying to access a restricted page. Kindly enter the password to gain access to the Admin page",
                          style: TextStyle(fontSize: 14)),
                      SizedBox(height: 15),
                      settingPassword(),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                ElevatedButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all<Color>(Color(0xff131e29)),
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.white),
                  ),
                  child: Text('Access'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const StaffDashboard()),
                      );
                      // Navigator.of().pop();
                      // if (!AppResponsive.isDesktop(context)) {
                      //   Navigator.of(context).pop();
                      // }
                      setPassword.clear();
                    }
                  },
                ),
              ],
            );
          });
        });
  }

  Container settingPassword() {
    return Container(
      decoration: ThemeHelper().inputBoxDecorationShaddow(),
      child: TextFormField(
          textInputAction: TextInputAction.done,
          obscureText: obscurePassword,
          keyboardType: TextInputType.text,
          controller: setPassword,
          onFieldSubmitted: (value) {
            FocusScope.of(context).requestFocus(loginButton);
          },
          decoration: ThemeHelper().textInputDecoration(
            "Password*",
            "Password*",
            "",
            const Icon(Icons.lock_outline),
          ),
          validator: (value) {
            if (value!.isEmpty) {
              return kPassNullError;
            } else if (value != settingsPin) {
              return "Invalid Password";
            }
            return null;
          }),
    );
  }

  Widget openHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        footerHeadTitle("Open Hours"),
        contactListItem(Icon(Icons.table_restaurant_outlined),
            "Weekdays: 8:30am - 11:30pm"),
        contactListItem(
            Icon(Icons.table_restaurant), "Saturday: 6:30am - 11:30pm"),
        contactListItem(
            Icon(Icons.table_restaurant_outlined), "Sunday: 2:30pam - 11:30pm"),
      ],
    );
  }

  Widget contactUs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        footerHeadTitle("Contact Us"),
        contactListItem(
            Icon(Icons.phone), "+233-00-000-0000\n+233-00-000-0000"),
        contactListItem(Icon(Icons.email_outlined), "menucook@dineease.org"),
        contactListItem(Icon(Icons.location_on_outlined),
            "52/1, Hasan Holdings, New\nEskaton Road, Dhaka, Bangladesh"),
      ],
    );
  }

  Widget contactListItem(Icon icon, String text) {
    return Container(
      constraints: BoxConstraints(maxWidth: double.infinity),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          icon,
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(fontWeight: FontWeight.w400),
              ),
              SizedBox(height: 10)
            ],
          ),
        ],
      ),
    );
  }

  Widget footerHeadTitle(title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // SizedBox(height: 30),
        Container(
          padding: EdgeInsets.all(25),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
        // SizedBox(height: 8),
      ],
    );
  }

  ImageFiltered footerImage(MediaQueryData mediaQueryData) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
      child: Container(
        width: mediaQueryData.size.width,
        height: 300,
        decoration: const BoxDecoration(
          image: DecorationImage(
              filterQuality: FilterQuality.low,
              colorFilter: ColorFilter.mode(Colors.white12, BlendMode.color),
              fit: BoxFit.cover,
              image: AssetImage("assets/banners/banner2.jpg")),
        ),
      ),
    );
  }

  Widget stepsWorks(icon, text) {
    return Expanded(
      child: Column(children: [
        icon,
        SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: AppResponsive.isTablet(context) ||
                      AppResponsive.isDesktop(context)
                  ? 15
                  : 12),
        ),
      ]),
    );
  }

  void updateOrders(orderId) {
    setState(() {
      finalOrderId;
      finalOrderId1;
      finalOrderId2;
      finalOrderId3;
      finalOrderId4;
      orderId;
    });
  }
}
