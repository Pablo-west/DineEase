// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, avoid_print, prefer_const_literals_to_create_immutables, depend_on_referenced_packages

// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../global.dart';
import '../main.dart';
import '../model/app_responsive.dart';

class HeaderWidget extends StatefulWidget {
  const HeaderWidget({
    super.key,
  });

  @override
  _HeaderWidgetState createState() => _HeaderWidgetState();
}

class _HeaderWidgetState extends State<HeaderWidget> {
  List<String> actions = <String>['Change Password', 'Logout'];

  onAction(String action) {
    switch (action) {
      case 'Change Password':
        break;
      case 'Logout':
        break;
    }
    if (action == 'Change Password') {
      // updatePassword();
      print("Change password");
      // showDialog(
      //   context: context,
      //   builder: (BuildContext context) {
      //     return Text("Change Password");
      //     // return ChangePassword();
      //   },
      // );
    } else {
      logoutOptn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      child: TextButton(
        onPressed: () {
          setState(() {
            logoutOptn();
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (AppResponsive.isBMobile(context))
              Container(
                // padding: const EdgeInsets.all(8.0),
                child: userName == null
                    ? Text('Admin',
                        style: TextStyle(
                            fontSize: AppResponsive.isTablet(context) ||
                                    AppResponsive.isDesktop(context)
                                ? 13
                                : 10))
                    : Text("$userName",
                        style: TextStyle(
                            fontSize: AppResponsive.isTablet(context) ||
                                    AppResponsive.isDesktop(context)
                                ? 13
                                : 10)),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton(
                // tooltip: "Logout",
                onSelected: onAction,
                icon: const Icon(Icons.toggle_on_sharp),
                itemBuilder: (BuildContext context) {
                  return actions.map((String action) {
                    return PopupMenuItem(
                        value: action,
                        child: Text(
                          action,
                          style: const TextStyle(fontSize: 15),
                        ));
                  }).toList();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<dynamic> logoutOptn() {
    return showDialog(
      context: context,
      builder: (content) => AlertDialog(
        title: Text("Please Confirm"),
        content: Text("Are you sure you want to logout?"),
        actions: [
          ElevatedButton(
              onPressed: () {
                Navigator.of(content).pop(false);
                // print(tokenData);
              },
              child: Text("Cancel")),
          ElevatedButton(
              style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  backgroundColor:
                      WidgetStateProperty.all<Color>(Color(0xff131e29))),
              onPressed: () {
                Navigator.of(context).pop(
                  MaterialPageRoute(builder: (context) => const MyApp()),
                );
                Navigator.of(content).pop(false);
              },
              child: Text("Logout")),
        ],
      ),
    );
  }

  // Future<void> logout(context) async {
  //   try {
  //     var routeUrl = '/api/logout';
  //     var fullUrl = baseUrl + routeUrl;
  //     var response = await http.post(
  //       Uri.parse(fullUrl),
  //       headers: {
  //         "Accept": "application/json",
  //         "authorization": "Bearer $tokenData"
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       setState(() {
  //         tokenData == null;
  //       });

  //       // tokenData == null;
  //       Navigator.of(context).push(
  //         MaterialPageRoute(builder: (context) => const MyApp()),
  //       );
  //     } else {}
  //   } catch (e) {
  //     print(e);
  //   }
  // }
}
