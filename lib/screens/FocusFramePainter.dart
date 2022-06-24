import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';


class FocusFramePainter extends CustomPainter
{
  Color _frameColor = Colors.yellow;
  Offset? _focusPosition = null;
  int _incrementSize = 0;

  FocusFramePainter(this._focusPosition, this._incrementSize, this._frameColor);

  @override
  void paint(Canvas canvas, Size size)
  {
      Offset? position = _focusPosition;
      if (position == null)
      {
          return;
      }


      Paint paint = new Paint();
      paint.color = this._frameColor;
      paint.strokeCap = StrokeCap.square;
      paint.style = PaintingStyle.stroke;

      var frame_length = size.width * 0.15;
      var increment_unit = frame_length * 0.08 * _incrementSize;
      var line_length = frame_length * 0.05;
      paint.strokeWidth = line_length;
      var offset = paint.strokeWidth/2;

      var rect =  Rect.fromCenter(
                          center: position,
                          width: frame_length - offset + increment_unit,
                          height: frame_length - offset + increment_unit);
      canvas.drawRect(rect, paint);

      // left
      canvas.drawLine(rect.centerLeft, Offset(rect.centerLeft.dx + line_length, rect.centerLeft.dy), paint);

      // top
      canvas.drawLine(rect.topCenter, Offset(rect.topCenter.dx, rect.topCenter.dy + line_length), paint);

      // right
      canvas.drawLine(rect.centerRight, Offset(rect.centerRight.dx - line_length, rect.centerRight.dy), paint);

      // bottom
      canvas.drawLine(rect.bottomCenter, Offset(rect.bottomCenter.dx, rect.bottomCenter.dy - line_length), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate)
  {
      return true;
  }
}