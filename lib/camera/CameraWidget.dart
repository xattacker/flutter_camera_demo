import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_camera_demo/util/Extension.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import 'CameraManager.dart';
import 'FocusScreenWidget.dart';
import 'PhotoBarWidget.dart';


abstract class CameraWidgetListener
{
    void onPictureTaken(List<File> pictures);
}

enum CameraStatus
{
  unstarted,
  permissionDenied,
  initialing,
  started,
  failed
}


class CameraWidget extends StatefulWidget
{
  late WeakReference<CameraWidgetListener> _listener;

  CameraWidget(CameraWidgetListener listener)
  {
    _listener = WeakReference(listener);
  }

  @override
  _CameraWidgetState createState() => _CameraWidgetState();
}


class _CameraWidgetState extends State<CameraWidget> with WidgetsBindingObserver {
  CameraStatus _status = CameraStatus.unstarted;
  CameraController? _cameraCtrl;
  VideoPlayerController? _videoCtrl;

  File? _imageFile;
  File? _videoFile;
  List<File> _allFileList = [];
  PhotoBarWidget _photoBarWidget = PhotoBarWidget();

  // Initial values
  CameraLensDirection _currentCameraDirection = CameraLensDirection.back;
  bool _isVideoCameraSelected = false;
  bool _isRecordingInProgress = false;
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  // Current values
  double _currentZoom = 1.0;
  // temp scale for Gesture Pinch
  double _tempZoom = 1.0;

  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;

  FocusScreenWidget _focusScreenWidget = FocusScreenWidget();
  ResolutionPreset _currentResolutionPreset = ResolutionPreset.high;

  void updateStatus(CameraStatus status)
  {
    setState(() {
      _status = status;
    });
  }

  getPermissionStatus() async {
    await Permission.camera.request();
    var status = await Permission.camera.status;

    if (status.isGranted) {
      debugPrint('Camera Permission: GRANTED');

      this.updateStatus(CameraStatus.initialing);

        // Set and initialize the new camera
        CameraDescription? camera = CameraManager().getCameraByDirection(CameraLensDirection.back);
        if (camera != null)
        {
            onNewCameraSelected(camera);
            _clearCapturedFiles();
        }
        else
        {
              this.updateStatus(CameraStatus.failed);
              context.showAlertDialog("Error", "There is no Camera");
        }
    }
    else
    {
        debugPrint('Camera Permission: DENIED');
        this.updateStatus(CameraStatus.permissionDenied);
        context.showAlertDialog("Error", "Camera Permission DENIED");
    }
  }

  _clearCapturedFiles() async
  {
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    _allFileList.clear();

    fileList.forEach((file) {
        file.delete(recursive: true);
    });

    setState(() {});
  }

  _refreshCapturedImages() async {
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = await directory.list().toList();
    _allFileList.clear();

    List<Map<int, dynamic>> fileNames = [];
    fileList.forEach((file) {
      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        _allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    });

    if (fileNames.isNotEmpty) {
      final recentFile = fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];

      if (recentFileName.contains('.mp4')) {
        _videoFile = File('${directory.path}/$recentFileName');
        _imageFile = null;
        _startVideoPlayer();
      } else {
        _imageFile = File('${directory.path}/$recentFileName');
        _photoBarWidget.addPhoto(_imageFile!);
        _videoFile = null;
      }

      setState(() {});
    }
  }

  void _take() async
  {
    if (_isVideoCameraSelected)
     {
        if (_isRecordingInProgress) {
          XFile? rawVideo = await stopVideoRecording();
          File videoFile = File(rawVideo!.path);

          int currentUnix = DateTime.now().millisecondsSinceEpoch;
          final directory = await getApplicationDocumentsDirectory();
          String fileFormat = videoFile.path.split('.').last;

          _videoFile = await videoFile.copy('${directory.path}/$currentUnix.$fileFormat');
          _startVideoPlayer();
        }
        else
        {
          await startVideoRecording();
        }
    }
    else
    {
          XFile? rawImage = await _takePicture();
          File imageFile = File(rawImage!.path);

          int currentUnix = DateTime.now().millisecondsSinceEpoch;

          final directory = await getApplicationDocumentsDirectory();
          String fileFormat = imageFile.path.split('.').last;
          debugPrint(fileFormat);

          await imageFile.copy('${directory.path}/$currentUnix.$fileFormat');
          _refreshCapturedImages();
    }
  }

  Future<XFile?> _takePicture() async {
    final CameraController? cameraController = _cameraCtrl;
    if (cameraController == null || cameraController.value.isTakingPicture == true) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      debugPrint('Error occurred while taking picture: $e');
      return null;
    }
  }

  Future<void> _startVideoPlayer() async {
    if (_videoFile != null) {
      _videoCtrl = VideoPlayerController.file(_videoFile!);
      await _videoCtrl?.initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized,
        // even before the play button has been pressed.
        setState(() {});
      });
      await _videoCtrl?.setLooping(true);
      await _videoCtrl?.play();
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = _cameraCtrl;
    if (cameraController == null || cameraController.value.isRecordingVideo == true) {
      // A recording has already started, do nothing.
      return;
    }

    try {
      await cameraController.startVideoRecording();
      setState(() {
        _isRecordingInProgress = true;
      });
    } on CameraException catch (e) {
      debugPrint('Error starting to record video: $e');
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (_cameraCtrl == null || _cameraCtrl?.value.isRecordingVideo == false) {
      // Recording is already is stopped state
      return null;
    }

    try {
      XFile? file = await _cameraCtrl?.stopVideoRecording();
      setState(() {
        _isRecordingInProgress = false;
      });
      return file;
    } on CameraException catch (e) {
      debugPrint('Error stopping video recording: $e');
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    if (_cameraCtrl == null || _cameraCtrl?.value.isRecordingVideo == false) {
      // Video recording is not in progress
      return;
    }

    try {
      await _cameraCtrl?.pauseVideoRecording();
    } on CameraException catch (e) {
      debugPrint('Error pausing video recording: $e');
    }
  }

  Future<void> resumeVideoRecording() async {
    if (_cameraCtrl == null || _cameraCtrl?.value.isRecordingVideo == false) {
      // No video recording was in progress
      return;
    }

    try {
      await _cameraCtrl?.resumeVideoRecording();
    } on CameraException catch (e) {
      debugPrint('Error resuming video recording: $e');
    }
  }

  void resetCameraValues() async {
    _currentZoom = 1.0;
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = _cameraCtrl;

    final CameraController cameraController = CameraController(
      cameraDescription,
      _currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await previousCameraController?.dispose();

    resetCameraValues();

    if (mounted) {
      setState(() {
        _cameraCtrl = cameraController;
      });
    }

    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxZoom = value <= 4 ? value : 4),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minZoom = value),
      ]);

      _currentFlashMode = _cameraCtrl?.value.flashMode;
    } on CameraException catch (e) {
      debugPrint('Error initializing camera: $e');
    }

    if (mounted)
    {
        updateStatus(_cameraCtrl?.value.isInitialized == true ? CameraStatus.started : CameraStatus.failed);
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (_cameraCtrl == null) {
      return;
    }

    final offset = Offset(
                          details.localPosition.dx / constraints.maxWidth,
                          details.localPosition.dy / constraints.maxHeight);
    _cameraCtrl?.setExposurePoint(offset);
    _cameraCtrl?.setFocusPoint(offset);

    _focusScreenWidget.focusPosition = details.localPosition;
  }

  void setZoomLvAsync(double zoom) async
  {
      if (_cameraCtrl == null)
      {
         return;
      }

        setState(() {
          _currentZoom = zoom;
        });

        await _cameraCtrl?.setZoomLevel(zoom);
  }

  void setZoomLv(double zoom)
  {
    if (_cameraCtrl == null)
    {
       return;
    }

    setState(() {
      _currentZoom = zoom;
    });

    _cameraCtrl?.setZoomLevel(zoom);
  }

  Widget _createMainWidget()
  {
    return Column(
      children: [
    Expanded(
    child:
            Stack(
            children: [
              Container(
                color: Colors.red,
              ),
            Center(
              child:
                AspectRatio(
                aspectRatio: 1, //1 /  (_cameraCtrl?.value.aspectRatio ?? 1),
                child:
                        CameraPreview(
                              _cameraCtrl!,
                              child: LayoutBuilder(builder:
                                  (BuildContext context, BoxConstraints constraints) {
                                return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (details) =>
                                        onViewFinderTap(details, constraints),
                                    onScaleStart: (ScaleStartDetails e) {
                                      _tempZoom = _currentZoom;
                                    },
                                    onScaleUpdate: (ScaleUpdateDetails e) {
                                      double orig_scale = e.scale.toDouble();
                                      double scale = orig_scale * _tempZoom;
                                      scale = scale.clamp(_minZoom, _maxZoom).toDouble();
                                      //print("onScaleUpdate $scale, $orig_scale");
                                      setZoomLv(scale.toDouble());
                                    },
                                    onScaleEnd: (ScaleEndDetails e) {
                                      _tempZoom = 0;
                                    }
                                );
                              }),
                            )
                        )
                   ),
                    IgnorePointer(
                        child: _focusScreenWidget // draw focus frame
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child:
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                          _currentExposureOffset.toStringAsFixed(1) + 'x',
                                          style: TextStyle(color: Colors.black)),
                                    ),
                                  ),
                                  Expanded(
                                    child:
                                    RotatedBox(
                                      quarterTurns: 3,
                                      child: Container(
                                        height: 30,
                                        child: Slider(
                                          value: _currentExposureOffset,
                                          min: _minExposureOffset,
                                          max: _maxExposureOffset,
                                          activeColor: Colors.white,
                                          inactiveColor: Colors.white30,
                                          onChanged: (value) async {
                                            setState(() {
                                              _currentExposureOffset = value;
                                            });
                                            await _cameraCtrl?.setExposureOffset(value);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ])
                    ),
            ],
        )
      ),
      Column(
              children: [
                _photoBarWidget,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: _isRecordingInProgress
                          ? () async {
                        if (_cameraCtrl?.value.isRecordingPaused == true) {
                          await resumeVideoRecording();
                        } else {
                          await pauseVideoRecording();
                        }
                      }
                          : () {
                        updateStatus(CameraStatus.initialing);

                        CameraDescription? camera = CameraManager().getCameraByDirection(_currentCameraDirection.theOther);
                        if (camera != null)
                        {
                          onNewCameraSelected(camera);

                          setState(() {
                            _currentCameraDirection = _currentCameraDirection.theOther;
                          });
                        }
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                              Icons.circle,
                              color: Colors.black38,
                              size: 60),
                          _isRecordingInProgress
                              ? _cameraCtrl?.value.isRecordingPaused == true
                              ? Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 30)
                              : Icon(
                              Icons.pause,
                              color: Colors.white,
                              size: 30)
                              : Icon(
                              _currentCameraDirection == CameraLensDirection.front ? Icons.camera_front : Icons.camera_rear,
                              color: Colors.white,
                              size: 30)
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _take();
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.circle,
                            color: _isVideoCameraSelected ? Colors.white : Colors.white38,
                            size: 80,
                          ),
                          Icon(
                            Icons.circle,
                            color: _isVideoCameraSelected ? Colors.red : Colors.white,
                            size: 65,
                          ),
                          _isVideoCameraSelected && _isRecordingInProgress
                              ? Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: 32,
                          )
                              : Container(),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      child: Text('Done', style: TextStyle(color: Colors.black)),
                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.white)),
                      onPressed: () {
                        this.widget._listener.target?.onPictureTaken(_allFileList);
                        Navigator.of(this.context).pop(true); // 返回前一頁
                      },
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                          child: TextButton(
                            onPressed: _isRecordingInProgress
                                ? null
                                : () {
                              if (_isVideoCameraSelected) {
                                setState(() {
                                  _isVideoCameraSelected = false;
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              primary: _isVideoCameraSelected ? Colors.black54 : Colors.black,
                              backgroundColor: _isVideoCameraSelected ? Colors.white30 : Colors.white,
                            ),
                            child: Text('IMAGE'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 4.0, right: 8.0),
                          child: TextButton(
                            onPressed: () {
                              if (!_isVideoCameraSelected) {
                                setState(() {
                                  _isVideoCameraSelected = true;
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              primary: _isVideoCameraSelected ? Colors.black : Colors.black54,
                              backgroundColor: _isVideoCameraSelected ? Colors.white : Colors.white30),
                            child: Text('VIDEO'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () async {
                          setState(() {
                            _currentFlashMode = FlashMode.off;
                          });

                          await _cameraCtrl?.setFlashMode(FlashMode.off);
                        },
                        child: Icon(
                          Icons.flash_off,
                          color:
                          _currentFlashMode == FlashMode.off
                              ? Colors.amber
                              : Colors.white,
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          setState(() {
                            _currentFlashMode = FlashMode.auto;
                          });
                          await _cameraCtrl?.setFlashMode(FlashMode.auto,);
                        },
                        child: Icon(
                          Icons.flash_auto,
                          color:
                          _currentFlashMode == FlashMode.auto
                              ? Colors.amber
                              : Colors.white,
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          setState(() {
                            _currentFlashMode = FlashMode.always;
                          });
                          await _cameraCtrl?.setFlashMode(FlashMode.always);
                        },
                        child: Icon(
                          Icons.flash_on,
                          color: _currentFlashMode == FlashMode.always ? Colors.amber : Colors.white,
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          setState(() {
                            _currentFlashMode = FlashMode.torch;
                          });
                          await _cameraCtrl?.setFlashMode(FlashMode.torch);
                        },
                        child: Icon(
                          Icons.highlight,
                          color: _currentFlashMode == FlashMode.torch ? Colors.amber : Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
      ],
    );
  }

  Widget _createLoadingWidget()
  {
      return Center(child: Text('LOADING', style: TextStyle(color: Colors.white)));
  }

  Widget _createPermissionDeniedWidget()
  {
    return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Row(),
              Text(
                'Permission denied',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  getPermissionStatus();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Give permission',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
              )
            ],
          );
  }

  Widget _createFailureWidget()
  {
    return Center(child: Text('Camera Load Failure', style: TextStyle(color: Colors.white)));
  }

  Widget _createStatusWidget()
  {
      switch (this._status)
      {
          case CameraStatus.unstarted:
             return _createLoadingWidget();

         case CameraStatus.permissionDenied:
              return _createPermissionDeniedWidget();

        case CameraStatus.initialing:
             return _createLoadingWidget();

        case CameraStatus.started:
             return _createMainWidget();

        case CameraStatus.failed:
            return _createFailureWidget();
      }
  }

  @override
  void initState() {
    // Hide the status bar in Android
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    Future.delayed(Duration(milliseconds: 300), () {
      getPermissionStatus();
    });

    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
    final CameraController? cameraController = _cameraCtrl;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
                child:
                  WillPopScope(
                  onWillPop: _onBackPressed,
                  child:
                  Scaffold(
                      backgroundColor: Colors.black,
                      body: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            _createStatusWidget(),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(16.0, 8.0, 0, 0),
                                    child:
                                    ElevatedButton(
                                      child: Text('Back', style: TextStyle(color: Colors.white)),
                                      style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.transparent)),
                                      onPressed: () {
                                        _onBackPressed();
                                      },
                                    ),
                                  )
                                ]
                            )
                          ])
                  )
                ),
    );
  }

  Future<bool> _onBackPressed() async {
    return await showDialog(
      context: context,
      builder: (context) =>
        new AlertDialog(
        title: Text('Confirm'),
        content: Text('Do you want to Exit ?'),
        actions: [
            Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
            TextButton(
                child: Text("NO", textAlign: TextAlign.center),
                onPressed: () {
                  Navigator.of(context).pop(false); //关闭对话框
                }),
              TextButton(
                  child: Text("YES", textAlign: TextAlign.center),
                  onPressed: () {
                    Navigator.of(context).pop(false); //关闭对话框
                    Navigator.of(this.context).pop(true); // 返回前一頁
                  }
              )
            ])
        ],
      ),
    ) ??
    false;
  }
}
