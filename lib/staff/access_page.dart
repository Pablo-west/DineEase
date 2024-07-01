// import 'package:flutter/material.dart';

// class AccessPage extends StatefulWidget {
//   const AccessPage({super.key});

//   @override
//   State<AccessPage> createState() => _AccessPageState();
// }

// class _AccessPageState extends State<AccessPage> {
//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }

//   // Future<dynamic> settingPin(BuildContext context) {
//   //   return showDialog(
//   //       context: context,
//   //       builder: (context) {
//   //         return Builder(builder: (context) {
//   //           return AlertDialog(
//   //             title: Text('Settings Page'),
//   //             content: SizedBox(
//   //               width: 200,
//   //               child: Form(
//   //                 key: _formKey,
//   //                 child: Column(
//   //                   mainAxisSize: MainAxisSize.min,
//   //                   children: <Widget>[
//   //                     Text(
//   //                         "You trying to access a restricted page. Kindly enter the password to gain access to the Settings page",
//   //                         style: TextStyle(fontSize: 14)),
//   //                     SizedBox(height: 15),
//   //                     settingPassword(),
//   //                   ],
//   //                 ),
//   //               ),
//   //             ),
//   //             actions: <Widget>[
//   //               ElevatedButton(
//   //                 child: Text('Cancel'),
//   //                 onPressed: () {
//   //                   Navigator.of(context).pop();
//   //                 },
//   //               ),
//   //               ElevatedButton(
//   //                 style: ButtonStyle(
//   //                   backgroundColor:
//   //                       MaterialStateProperty.all<Color>(AppColor.bgSideMenu),
//   //                   foregroundColor:
//   //                       MaterialStateProperty.all<Color>(Colors.white),
//   //                 ),
//   //                 child: Text('Access'),
//   //                 onPressed: () {
//   //                   if (_formKey.currentState!.validate()) {
//   //                     Navigator.of(context).pop();
//   //                     widget.onIndexChanged(8);
//   //                     if (!AppResponsive.isDesktop(context)) {
//   //                       Navigator.of(context).pop();
//   //                     }
//   //                     setPassword.clear();
//   //                   }
//   //                 },
//   //               ),
//   //             ],
//   //           );
//   //         });
//   //       });
//   }

//   Container settingPassword() {
//     return Container(
//       decoration: ThemeHelper().inputBoxDecorationShaddow(),
//       child: TextFormField(
//           textInputAction: TextInputAction.done,
//           obscureText: obscurePassword,
//           keyboardType: TextInputType.text,
//           controller: setPassword,
//           onFieldSubmitted: (value) {
//             FocusScope.of(context).requestFocus(loginButton);
//           },
//           decoration: ThemeHelper().textInputDecoration(
//             "Password*",
//             "Password*",
//             "",
//             const Icon(Icons.lock_outline),
//           ),
//           validator: (value) {
//             if (value!.isEmpty) {
//               return kPassNullError;
//             } else if (value != settingsPin) {
//               return "Invalid Password";
//             }
//             return null;
//           }),
//     );
//   }