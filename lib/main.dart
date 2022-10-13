import 'package:flutter/material.dart';
import 'package:flutter_camera_demo/MainWidget.dart';
import 'camera/CameraManager.dart';
import 'camera/CameraWidget.dart';

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  CameraManager().initial((ex) {
    debugPrint('Error in fetching the cameras: $ex');
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: MainWidget(),
    );
  }
}
