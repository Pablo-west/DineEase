// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';

import '../model/app_responsive.dart';
import 'dashboard.dart';
import 'header_widget.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: Size.fromHeight(65.0),
          child: AppBar(
            backgroundColor: Colors.brown.shade100,
            leading: Icon(Icons.padding),
            title: Container(
              padding: EdgeInsets.only(left: 10),
              child: Row(
                children: [
                  SizedBox(width: AppResponsive.isMobile(context) ? 0 : 50),
                  Text(
                    'cheif @ MenuMate',
                    style: TextStyle(
                        fontSize: AppResponsive.isMobile(context) ? 12 : 18),
                  ),
                ],
              ),
            ),
            actions: [HeaderWidget(title: "Pharm Application")],
          )),
      body: Container(
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(10),
        child: DashboardBody(),
      ),
    );
  }
}
