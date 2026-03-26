// ignore_for_file: prefer_const_constructors, avoid_print
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('foods').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: AppResponsive.isMobile(context) ? 120 : 230,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final popularFoods = docs
            .map((doc) => {
                  ...doc.data(),
                  'docId': doc.id,
                })
            .where((data) {
              final foodTypes = (data['foodType'] as List?) ?? const [];
              return foodTypes
                  .map((item) => item.toString().toLowerCase())
                  .contains('popularfood');
            })
            .toList();

        if (popularFoods.isEmpty) {
          return SizedBox(
            height: AppResponsive.isMobile(context) ? 120 : 230,
            child: const Center(
              child: Text('Popular foods will appear here.'),
            ),
          );
        }

        return CarouselSlider.builder(
          itemBuilder: (context, index, realIndex) {
            final food = popularFoods[index];
            return PlaceOrderDialog(
              food: food,
            );
          },
          itemCount: popularFoods.length,
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
            reverse: false,
          ),
        );
      },
    );
  }
}

class PlaceOrderDialog extends StatefulWidget {
  final Map<String, dynamic> food;

  const PlaceOrderDialog({
    super.key,
    required this.food,
  });

  @override
  State<PlaceOrderDialog> createState() => _PlaceOrderDialogState();
}

class _PlaceOrderDialogState extends State<PlaceOrderDialog> {
  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);
    final imageUrl = widget.food['imageUrl']?.toString() ?? '';

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
        margin: AppResponsive.isMobile(context)
            ? EdgeInsets.all(5)
            : EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          color: Colors.grey.shade200,
          image: imageUrl.isEmpty
              ? null
              : DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
        ),
        child: imageUrl.isEmpty
            ? const Icon(Icons.image_not_supported)
            : null,
      ),
    );
  }

  Future<dynamic> viewDesktop(
    BuildContext context,
    MediaQueryData mediaQueryData,
  ) {
    return showDialog(
      barrierDismissible: finalOrderId4 != null ? true : false,
      context: context,
      builder: (context) {
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
                    imagePath: widget.food['imageUrl']?.toString() ?? '',
                    foodName: widget.food['title']?.toString() ?? 'Food',
                    imagePrice: _displayPrice(widget.food['price']),
                    foodId: widget.food['docId']?.toString() ?? '',
                    vendorId: widget.food['vendorId']?.toString() ?? '',
                    vendorName: widget.food['vendorName']?.toString() ?? '',
                    category: widget.food['category']?.toString() ?? '',
                    description: widget.food['description']?.toString() ?? '',
                  )
                : Center(
                    child: Text(
                      textAlign: TextAlign.center,
                      'Your orders are pending. Kindly wait to be served\nThank You.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
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
        ),
      ),
      context: context,
      builder: (context) {
        return SizedBox(
          child: finalOrderId4 == null
              ? PlaceOdrer(
                  imagePath: widget.food['imageUrl']?.toString() ?? '',
                  foodName: widget.food['title']?.toString() ?? 'Food',
                  imagePrice: _displayPrice(widget.food['price']),
                  foodId: widget.food['docId']?.toString() ?? '',
                  vendorId: widget.food['vendorId']?.toString() ?? '',
                  vendorName: widget.food['vendorName']?.toString() ?? '',
                  category: widget.food['category']?.toString() ?? '',
                  description: widget.food['description']?.toString() ?? '',
                )
              : Center(
                  child: Text(
                    textAlign: TextAlign.center,
                    'Your orders are pending. Kindly wait to be served\nThank You.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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

  String _displayPrice(dynamic raw) {
    if (raw is num) {
      return raw.toStringAsFixed(2);
    }
    return raw?.toString() ?? '0.00';
  }
}
