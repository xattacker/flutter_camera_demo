import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';

class CameraManager
{
  List<CameraDescription> _cameras = [];

  CameraDescription? getCamera(int index)
  {
       if (_cameras.isEmpty || index < 0 || index >= _cameras.length)
       {
         return null;
       }

       return _cameras[index];
  }

  CameraDescription? getCameraByDirection(CameraLensDirection direction)
  {
        if (_cameras.isEmpty)
        {
            return null;
        }

        return  _cameras.firstWhere((element) => element.lensDirection == direction);
  }

  int get cameraCount => _cameras.length;

  // singleton pattern
  CameraManager._internal();
  factory CameraManager() => _instance;
  static late final CameraManager _instance = CameraManager._internal();

  initial(void Function(CameraException ex) errorCallback) async {
    // Fetch the available cameras before initializing the app.
    try {
      WidgetsFlutterBinding.ensureInitialized();
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      errorCallback(e);
    }
  }
}


extension CameraLensDirectionExtension on CameraLensDirection
{
    CameraLensDirection get theOther
    {
        switch (this)
        {
          case CameraLensDirection.front:
              return CameraLensDirection.back;

          case CameraLensDirection.back:
            return CameraLensDirection.front;

          default:
            return this;
        }
    }
}