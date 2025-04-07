import 'package:flutter/material.dart';

final ThemeData climateActionTheme = ThemeData(
  textTheme: TextTheme(
    displayLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: Colors.green),
    titleLarge: TextStyle(fontSize: 20.0, fontStyle: FontStyle.italic, color: Colors.green),
    bodyMedium: TextStyle(fontSize: 14.0, color: Colors.black),
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: Colors.green,
    textTheme: ButtonTextTheme.primary,
  ),
  appBarTheme: AppBarTheme(
    color: Colors.green, toolbarTextStyle: TextTheme(
      titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
    ).bodyMedium, titleTextStyle: TextTheme(
      titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
    ).titleLarge,
  ),
  iconTheme: IconThemeData(
    color: Colors.green,
  ), colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(secondary: Colors.blueAccent).copyWith(surface: Colors.white),
);