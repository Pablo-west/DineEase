// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_literals_to_create_immutables, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../global.dart';
import '../model/app_responsive.dart';
import '../model/constant.dart';
import '../model/theme_helper.dart';
import 'database.dart';

class PlaceOdrer extends StatefulWidget {
  final String imagePath;
  final String foodName;
  final String imagePrice;
  final String foodId;
  final String vendorId;
  final String vendorName;
  final String category;
  final String description;

  const PlaceOdrer({
    super.key,
    required this.imagePath,
    required this.foodName,
    required this.imagePrice,
    required this.foodId,
    required this.vendorId,
    required this.vendorName,
    required this.category,
    required this.description,
  });

  @override
  State<PlaceOdrer> createState() => _PlaceOdrerState();
}

class _PlaceOdrerState extends State<PlaceOdrer> {
  String? dropdownPaymentOpt;

  final TextEditingController tableNumController = TextEditingController();
  final TextEditingController userNameontroller = TextEditingController();
  final TextEditingController paymentOptionController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(right: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Spacer(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: ' Dine',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 25,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Ease',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text('Place your order'),
                        ],
                      ),
                      Spacer(),
                      IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.close_outlined),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  child: AppResponsive.isTablet(context) ||
                          AppResponsive.isDesktop(context)
                      ? tableNdesktopView(context)
                      : mobileView(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Column mobileView(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: foodLabel(widget.imagePath, widget.foodName),
        ),
        SizedBox(height: 15),
        Container(
          height: 420,
          margin: EdgeInsets.symmetric(horizontal: 15),
          child: ListView(
            padding: EdgeInsets.only(left: 10, right: 10),
            children: [
              formOrder(context),
              SizedBox(height: 20),
              Divider(thickness: 3, color: Colors.brown),
              SizedBox(height: 30),
              _foodDetailsPanel(),
              SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  Form formOrder(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Fill the form below to place order',
              style: TextStyle(fontSize: 17),
            ),
          ),
          SizedBox(height: 15),
          entryTextField(
            TextInputType.number,
            tableNumController,
            'Enter your table number',
            'Eg: 03',
          ),
          SizedBox(height: 10),
          entryTextField(
            TextInputType.text,
            userNameontroller,
            'Enter your Name',
            'Eg: Pablo West',
          ),
          SizedBox(height: 10),
          textDropdown(
            'Payment Mode',
            30,
            150,
            dropdownPaymentOpt,
            (String? value) {
              setState(() {
                dropdownPaymentOpt = value!;
              });
            },
            paymentOptArray,
          ),
          foodAmount(),
          SizedBox(height: 30),
          rowActionButton(context),
        ],
      ),
    );
  }

  Stack foodLabel(String imagePath, String foodName) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Card(
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: _imageProvider(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            color: Colors.amber,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              foodName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Padding tableNdesktopView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 20, top: 20),
      child: Row(
        children: [
          SizedBox(
            height: 500,
            width: 350,
            child: foodLabel(widget.imagePath, widget.foodName),
          ),
          Container(
            width: 300,
            height: 400,
            margin: EdgeInsets.only(left: 30, right: 40),
            child: formOrder(context),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 50),
              child: _foodDetailsPanel(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodDetailsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vendor Details',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 10),
        Text(
          widget.vendorName.isEmpty
              ? 'Vendor assigned at checkout'
              : 'Vendor: ${widget.vendorName}',
        ),
        if (widget.category.isNotEmpty) Text('Category: ${widget.category}'),
        SizedBox(height: 30),
        Text(
          'Signature ${widget.foodName}',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 10),
        Text(
          widget.description.isEmpty
              ? 'Freshly prepared and listed by one of our food vendors for today.'
              : widget.description,
          textAlign: TextAlign.justify,
        ),
        SizedBox(height: 10),
        Text(
          'Your order will be routed directly to the vendor queue for preparation.',
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }

  Text foodAmount() {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'GHS: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          TextSpan(
            text: widget.imagePrice,
            style: TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 40,
            ),
          ),
        ],
      ),
    );
  }

  Row rowActionButton(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (isLoading != true)
          actionButton(
            () {
              Navigator.of(context).pop();
            },
            Colors.grey,
            'CANCEL',
          ),
        isLoading
            ? Center(
                child: SpinKitThreeBounce(
                  color: Colors.black45,
                  size: 30.0,
                  duration: Duration(milliseconds: 900),
                ),
              )
            : actionButton(() async {
                setState(() {
                  isLoading = true;
                });

                final id = DateTime.now().toIso8601String();
                final mealNum = DateTime.now().millisecond.toString();
                final numericPrice = double.tryParse(widget.imagePrice) ?? 0;

                if (formKey.currentState!.validate()) {
                  final orderInfoMap = {
                    'timestamp': id,
                    'mealNum': mealNum,
                    'food': widget.foodName,
                    'foodAmt': 'GHS ${widget.imagePrice}',
                    'foodId': widget.foodId,
                    'vendorId': widget.vendorId,
                    'vendorName': widget.vendorName,
                    'vendorIds': [widget.vendorId],
                    'vendorNames': [widget.vendorName],
                    'tableNum': tableNumController.text,
                    'userName': userNameontroller.text,
                    'paymentOption': dropdownPaymentOpt,
                    'kitchenMode': 'false',
                    'deliveredMode': 'false',
                    'stage': 'placed',
                    'placedAt': FieldValue.serverTimestamp(),
                    'orderNumber': mealNum,
                    'userId': 'guest',
                    'user': {
                      'name': userNameontroller.text.trim(),
                      'phone': '',
                    },
                    'payment': {
                      'method': dropdownPaymentOpt,
                    },
                    'delivery': {
                      'type': 'table',
                      'tableNumber': tableNumController.text.trim(),
                    },
                    'totals': {
                      'subtotal': numericPrice,
                      'total': numericPrice,
                    },
                    'items': [
                      {
                        'foodId': widget.foodId,
                        'title': widget.foodName,
                        'price': numericPrice,
                        'quantity': 1,
                        'vendorId': widget.vendorId,
                        'vendorName': widget.vendorName,
                        'category': widget.category,
                        'imageUrl': widget.imagePath,
                      },
                    ],
                  };

                  await DatabaseMethods()
                      .addOrder(orderInfoMap, id)
                      .then((value) {
                    Fluttertoast.showToast(
                      msg: 'Your order has been placed successfully',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.CENTER,
                      timeInSecForIosWeb: 3,
                      backgroundColor: Colors.greenAccent,
                      textColor: Colors.white,
                      fontSize: 15.0,
                    );
                    storeOrderId(mealNum);
                    incrementCounter(mealNum);
                  }).catchError((error) {
                    Fluttertoast.showToast(
                      msg: 'Error placing order: $error',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.CENTER,
                      timeInSecForIosWeb: 3,
                      backgroundColor: Colors.redAccent,
                      textColor: Colors.white,
                      fontSize: 15.0,
                    );
                  });

                  Navigator.of(context).pop();
                } else {
                  unfilledField(context);
                }

                setState(() {
                  isLoading = false;
                });
              }, Colors.green, 'ORDER'),
      ],
    );
  }

  Widget entryTextField(
    TextInputType keyboardType,
    TextEditingController controller,
    String lableText,
    String textHint,
  ) {
    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: TextFormField(
        textInputAction: TextInputAction.next,
        keyboardType: keyboardType,
        controller: controller,
        style: TextStyle(fontSize: 13),
        decoration: ThemeHelper().textInputDecoration(
          lableText,
          '',
          textHint,
          null,
          null,
        ),
        validator: (value) {
          if (value!.isEmpty) {
            return kNullValue;
          }

          return null;
        },
      ),
    );
  }

  ElevatedButton actionButton(VoidCallback press, Color color, String title) {
    return ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all<Color>(color),
        foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
      ),
      onPressed: press,
      child: Text(title),
    );
  }

  Widget textDropdown(
    String textName,
    double height,
    double width,
    String? dropdownValue,
    ValueChanged<String?> onChanged,
    List itemMap,
  ) {
    return Row(
      children: [
        Text(textName),
        const SizedBox(width: 10.0),
        dropDownListWidget(height, width, dropdownValue, onChanged, itemMap),
      ],
    );
  }

  Center dropDownListWidget(
    double height,
    double width,
    String? dropdownValue,
    ValueChanged<String?> onChanged,
    List itemMap,
  ) {
    return Center(
      child: Container(
        height: 50,
        width: width,
        margin: EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.zero,
        child: DropdownButtonHideUnderline(
          child: DropdownButtonFormField<String>(
            initialValue: dropdownValue,
            dropdownColor: Colors.white,
            icon: const Icon(
              Icons.arrow_drop_down_rounded,
              color: Colors.black,
            ),
            isExpanded: true,
            elevation: 16,
            style: const TextStyle(color: Colors.black),
            onChanged: onChanged,
            items: itemMap.map<DropdownMenuItem<String>>((dynamic value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: kDefaultIconDarkColor,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              );
            }).toList(),
            decoration: InputDecoration(
              hintText: 'Select an option',
              hintStyle: TextStyle(fontSize: 14),
              fillColor: Colors.white,
              hoverColor: Colors.white10,
              filled: true,
              border: InputBorder.none,
              contentPadding: EdgeInsetsDirectional.only(bottom: 15, start: 10),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.0),
                borderSide: BorderSide(color: Colors.red.shade200, width: 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.0),
                borderSide: BorderSide(color: Colors.red.shade200, width: 1.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.0),
                borderSide: BorderSide(color: Colors.red, width: 2.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5.0),
                borderSide: BorderSide(color: Colors.red, width: 2.0),
              ),
            ),
            validator: (value) {
              if (value == null) {
                return 'Please select an option';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Future<dynamic> unfilledField(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Center(
            child: FaIcon(
              FontAwesomeIcons.triangleExclamation,
              size: 50,
              color: Colors.redAccent,
            ),
          ),
          content: Text(
            'You left out some required field(s).',
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  ImageProvider _imageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return AssetImage(path);
  }
}
