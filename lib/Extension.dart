

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

extension BuildContextExtension on BuildContext
{
  void showAlertDialog(String title, String content, {VoidCallback? onPressed = null })
  {
      showDialog(
          context: this,
          barrierDismissible: false, // disable dismissed when clicking  dialog outside
          builder: (context) {
            return new AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                            child: Text("OK", textAlign: TextAlign.center),
                            onPressed: () {
                              Navigator.of(context).pop(); //关闭对话框
                              onPressed?.call();
                            }
                        )
                      ])
                ]
            );
          });
  }
}