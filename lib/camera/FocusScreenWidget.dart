import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiver/async.dart';

import 'FocusFramePainter.dart';

class FocusScreenWidget extends StatefulWidget
{
    Offset? _focusPosition = null;

    late _FocusScreenState _state;

    CountdownTimer? _countDownTimer;
    int _incrementSize = 0;

    set focusPosition(Offset position) {
        _state.setState(() {
            _focusPosition = position;
        });

        //_countDownTimer?.cancel();
        _incrementSize = 3;
        _countDownTimer = CountdownTimer(Duration(milliseconds: 800), Duration(milliseconds: 100));

        var listener = _countDownTimer?.listen(null);
        listener?.onData((data) {
            //print("onData ${ data.elapsed.inMilliseconds }");
            if (_incrementSize > 0)
            {
                _incrementSize--;
                _state.setState(() {
                });
            }
        });

        listener?.onDone(() {
            if (_countDownTimer?.isRunning == false)
            {
                _state.setState(() {
                    _focusPosition = null;
                });
            }
        });
    }

    @override
    State<StatefulWidget> createState()
    {
        _state = _FocusScreenState();
        return _state;
    }
}


class _FocusScreenState extends State<FocusScreenWidget>
{
    @override
    Widget build(BuildContext context)
    {
        return Opacity(
                    opacity: 1 / (this.widget._incrementSize + 1), //  let opacity change with increment
                    child:
                    CustomPaint(
                        size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.width),
                        painter: FocusFramePainter(this.widget._focusPosition, this.widget._incrementSize, Colors.yellow)
                    ));
    }
}