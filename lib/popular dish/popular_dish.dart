// ignore_for_file: prefer_const_constructors, avoid_print
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../global.dart';
import '../model/app_responsive.dart';
import '../orders/place_order.dart';

class PopularDish extends StatefulWidget {
  const PopularDish({super.key});

  @override
  State<PopularDish> createState() => _PopularDishState();
}

class _PopularDishState extends State<PopularDish> {
  //images of dishes
  final List<String> imagesPaths = [
    'assets/special/meal15.png',
    'assets/special/beans.jpg',
    'assets/special/frenchfriesSp.jpg',
    'assets/special/jolloriceSpe.jpg',
    'assets/special/waakyeSpe.jpg',
    'assets/special/yam.jpg',
    'assets/special/meal4.jpeg',
    'assets/special/waakye.jpg',
    'assets/special/oilriceSpe.jpg',
    'assets/special/ricenstew.jpg',
  ];
  //names of dishes
  final List<String> imageName = [
    'Jollof Rice - medium',
    'Gari and Beans',
    'French with Cat Fish',
    'Jollof Rice - large',
    'Waakye - large',
    'Yam',
    'Jollof Rice',
    'Waakye',
    'Oil Rice',
    'Rice with stew',
  ];

  //Amount of each dish
  final List<String> imagePrice = [
    '100.00',
    '70.00',
    '230.00',
    '180.00',
    '130.00',
    '80.00',
    '85.00',
    '90.00',
    '70.00',
    '90.00',
  ];

  @override
  Widget build(BuildContext context) {
    //controls the sliding of popular dishes available
    return CarouselSlider.builder(
      itemBuilder: (context, index, realIndex) {
        return PlaceOrderDialog(
          imagePath: imagesPaths[index],
          foodName: imageName[index],
          imagePrice: imagePrice[index],
        );
      },
      itemCount: imagesPaths.length,
      options: CarouselOptions(
        height: AppResponsive.isMobile(context) ? 120 : 230,
        enlargeCenterPage: true,
        enlargeStrategy: CenterPageEnlargeStrategy.height,
        autoPlay: true,
        enlargeFactor: AppResponsive.isMobile(context) ? 0.2 : 0.1,
        viewportFraction: AppResponsive.isMobile(context) ? 0.28 : 0.2,
        autoPlayInterval: Duration(seconds: 3),
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: true,
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        // initialPage: 0,
        reverse: false,
        // scrollDirection: Axis.horizontal,
      ),
    );
  }
}

class PlaceOrderDialog extends StatefulWidget {
  final String imagePath;
  final String foodName;
  final String imagePrice;
  const PlaceOrderDialog({
    super.key,
    required this.imagePath,
    required this.foodName,
    required this.imagePrice,
  });

  @override
  State<PlaceOrderDialog> createState() => _PlaceOrderDialogState();
}

class _PlaceOrderDialogState extends State<PlaceOrderDialog> {
  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    //A pop up to view more details of each dish selected
    return GestureDetector(
      onTap: () {
        if (!AppResponsive.isMobile(context)) {
          viewDesktop(context, mediaQueryData);
        }

        if (AppResponsive.isMobile(context)) {
          showMobile(context);
        }
      },
      child: Container(
          // height: 5,
          margin: AppResponsive.isMobile(context)
              ? EdgeInsets.all(5)
              : EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            image: DecorationImage(
                image: AssetImage(widget.imagePath), fit: BoxFit.cover),
          )),
    );
  }

  Future<dynamic> viewDesktop(
      BuildContext context, MediaQueryData mediaQueryData) {
    return showDialog(
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
                      imagePath: widget.imagePath,
                      foodName: widget.foodName,
                      imagePrice: widget.imagePrice,
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
    ).then((value) {
      setState(() {
        finalOrderId;
        finalOrderId1;
        finalOrderId2;
        finalOrderId3;
        finalOrderId4;
      });
    });
  }

  Future<dynamic> showMobile(BuildContext context) {
    return showModalBottomSheet(
        isDismissible: finalOrderId4 != null ? true : false,
        isScrollControlled: true,
        enableDrag: false,
        useRootNavigator: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        )),
        context: context,
        builder: (context) {
          return SizedBox(
            child: finalOrderId4 == null
                ? PlaceOdrer(
                    imagePath: widget.imagePath,
                    foodName: widget.foodName,
                    imagePrice: widget.imagePrice,
                  )
                : Center(
                    child: Text(
                    textAlign: TextAlign.center,
                    "Your orders are pending. Kindly wait to be served\nThank You.",
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 25,
                        fontWeight: FontWeight.bold),
                  )),
          );
        }).then((value) {
      setState(() {
        finalOrderId;
        finalOrderId1;
        finalOrderId2;
        finalOrderId3;
        finalOrderId4;
      });
    });
  }
}
