// ignore_for_file: prefer_const_constructors, avoid_print

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';

import '../global.dart';
import '../model/app_responsive.dart';
import '../model/constant.dart';
import '../orders/place_order.dart';

class MenuList extends StatefulWidget {
  final dynamic mediaQueryData;

  const MenuList({super.key, required this.mediaQueryData});

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  final List<Map<String, dynamic>> _items = [
    {
      'name': 'Banku and Pepper\n[Meat]',
      'image': 'assets/food/bankuwithmeat.jpg',
      'price': '70.00'
    },
    {'name': 'Yam', 'image': 'assets/food/yam1.jpg', 'price': '50.00'},
    {'name': 'Fufu ', 'image': 'assets/food/fufu.jpg', 'price': '60.00'},
    {
      'name': 'Gari with meat',
      'image': 'assets/food/gari.jpg',
      'price': '55.00'
    },
    {
      'name': 'Banku and Okro\n[Meat & Fish]',
      'image': 'assets/food/meal13.jpeg',
      'price': '85.00'
    },
    {'name': 'Waakye ', 'image': 'assets/food/meal1.jpeg', 'price': '40.00'},
    {
      'name': 'Baked Chiken',
      'image': 'assets/food/meal12.jpeg',
      'price': '160.00'
    },
    {
      'name': 'Banku and Pepper\n[Tilapia]',
      'image': 'assets/food/bankwithfish1.jpg',
      'price': '80.00'
    },
    {
      'name': 'French with Chiken',
      'image': 'assets/food/frenchfries.jpg',
      'price': '70.00'
    },
    {
      'name': 'French with vegs',
      'image': 'assets/food/meal7.jpeg',
      'price': '50.00'
    },
    {
      'name': 'Banku and Pepper\n[Red Fish] ',
      'image': 'assets/food/bankwithfish.jpg',
      'price': '90.00'
    },
    {
      'name': 'Jollof Rice ',
      'image': 'assets/food/meal11.jpg',
      'price': '100.00'
    }
  ];

  final ScrollController controllerOne = ScrollController();
  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);

    return Scaffold(
      body: Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.black54),
              crossAxisMargin: 3),
        ),
        child: Scrollbar(
          controller: controllerOne,
          thumbVisibility: true,
          trackVisibility: true,
          child: Stack(
            children: [
              footerImage(mediaQueryData),
              ListView(
                controller: controllerOne,
                scrollDirection: Axis.vertical,
                // crossAxisAlignment: CrossAxisAlignment.center,
                // mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    margin: AppResponsive.isMobile(context)
                        ? EdgeInsets.symmetric(horizontal: 5)
                        : EdgeInsets.symmetric(horizontal: 10),
                    child: MasonryView(
                        itemPadding: AppResponsive.isMobile(context) ? 5 : 10,
                        itemRadius: 20,
                        listOfItem: _items,
                        numberOfColumn: AppResponsive.isTablet(context) ||
                                AppResponsive.isDesktop(context) ||
                                AppResponsive.isBMobile(context)
                            ? 3
                            : 2,
                        itemBuilder: (item) {
                          return profileCard(
                              item['image'], item['name'], item['price']);
                        }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget profileCard(var cardImage, cardName, cardPrice) {
    return Card(
      elevation: 10,
      color: Colors.white12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: MenuViewCard(
          cardPrice: cardPrice,
          cardName: cardName,
          cardImage: cardImage,
          mediaQueryData: widget.mediaQueryData),
    );
  }

  ImageFiltered footerImage(MediaQueryData mediaQueryData) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
      child: Container(
        width: mediaQueryData.size.width,
        height: mediaQueryData.size.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
              filterQuality: FilterQuality.low,
              colorFilter: ColorFilter.mode(Colors.white12, BlendMode.color),
              fit: BoxFit.fill,
              image: AssetImage("assets/banners/banner2.jpg")),
        ),
      ),
    );
  }
}

class MenuViewCard extends StatefulWidget {
  final String cardPrice;
  final String cardName;
  final String cardImage;
  final dynamic mediaQueryData;

  const MenuViewCard({
    super.key,
    required this.cardPrice,
    required this.cardName,
    required this.cardImage,
    required this.mediaQueryData,
  });

  @override
  State<MenuViewCard> createState() => _MenuViewCardState();
}

class _MenuViewCardState extends State<MenuViewCard> {
  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);

    // var mediaQueryData;
    return GestureDetector(
      onTap: () {
        showDialog(
          barrierDismissible: finalOrderId4 != null ? true : false,
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Container(
                  width: double.infinity,
                  height: finalOrderId4 != null
                      ? 200
                      : mediaQueryData.size.height / 1.2,
                  padding: EdgeInsets.only(top: 16),
                  child: finalOrderId4 == null
                      ? PlaceOdrer(
                          imagePath: widget.cardImage,
                          foodName: widget.cardName,
                          imagePrice: widget.cardPrice,
                        )
                      : Center(
                          child: Text(
                          textAlign: TextAlign.center,
                          "Your orders are pending. Kindly wait to be served\nThank You.",
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 25,
                              fontWeight: FontWeight.bold),
                        ))),
            );
          },
        );
      },
      child: SizedBox(
        width: widget.mediaQueryData.size.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 15, bottom: 15),
              child: SizedBox(
                height: 150,
                width: widget.mediaQueryData.size.width * 2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                        image: AssetImage(widget.cardImage), fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.cardName,
                          textAlign: TextAlign.left,
                          style: MenuListStyle.menuName,
                        ),
                        Text(
                          "GHS ${widget.cardPrice}",
                          textAlign: TextAlign.left,
                          style: MenuListStyle.menuDetails,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
