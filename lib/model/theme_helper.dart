// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, non_constant_identifier_names, avoid_print

import 'package:flutter/material.dart';

class ThemeHelper {
  InputDecoration textInputDecoration([
    String lableText = "",
    String hintText = "",
    String helperText = "",
    final prefixIcon,
    final suffixIcon,
  ]) {
    return InputDecoration(
      contentPadding: EdgeInsets.fromLTRB(8, 0, 8, 0),
      labelStyle: TextStyle(
          fontSize: 12,
          color: kDefaultIconDarkColor,
          fontWeight: FontWeight.w300),
      hintStyle: TextStyle(
          fontSize: 12,
          color: kDefaultIconDarkColor,
          fontWeight: FontWeight.w300),
      helperText: helperText,
      labelText: lableText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      fillColor: Colors.white,
      hoverColor: Colors.white10,
      filled: true,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: BorderSide(color: Colors.blueGrey.shade200, width: 1.0)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: BorderSide(color: Colors.blueGrey.shade200, width: 1.0)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: BorderSide(color: Colors.red, width: 2.0)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: BorderSide(color: Colors.red, width: 2.0)),
    );
  }

  BoxDecoration inputBoxDecorationShaddow() {
    return BoxDecoration(boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.0),
        blurRadius: 20,
        offset: const Offset(0, 5),
      )
    ]);
  }
}
