// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseMethods {
  Future<void> addOrder(Map<String, dynamic> orderInfoMap, String id) async {
    try {
      await FirebaseFirestore.instance
          .collection("Order")
          .doc(id)
          .set(orderInfoMap);
    } catch (e) {
      // Handle error here
      print("Error adding order: $e");
    }
  }

  Future<Stream<QuerySnapshot>> getOrder() async {
    return FirebaseFirestore.instance
        .collection("Order")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
}
