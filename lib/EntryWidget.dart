import 'dart:developer';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera_demo/camera/CameraWidget.dart';

import 'util/SlidedPageRouteBuilder.dart';


class MainWidget extends StatelessWidget implements CameraWidgetListener
{
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: Text("CameraDemo"),
        ),
        body: SafeArea(
            child: Center(
                child:
                ElevatedButton(
                  child: Text('按鈕'),
                  onPressed: () {
                  Navigator.push(
                    context,
                      CupertinoPageRoute(builder: (context) => CameraWidget(this))
                  );
                },
              )
            )
        ));
  }

  @override
  void onPictureTaken(List<File> pictures)
  {
      debugPrint("onPictureTaken: "  + pictures.length.toString());
  }
}