import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:light/light.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera App',
      theme: ThemeData.dark(),
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver, TickerProviderStateMixin{
  late CameraController? _cameraController;
  StreamSubscription<CameraImage>? _cameraImageSubscription;
  double _grayscaleValue = 0.0;
  double _brightnessValue = 0.0;

  ///sensor
  String _luxString = 'Unknown';
  Light? _light;
  StreamSubscription? _subscription;


  ///VIKAS
  bool _isLowLight = false;
  bool _isBadLighting = false;

  ///  ///EXPOSURE SETTINGS
  double _minAvailableExposureOffset = -1;
  double _maxAvailableExposureOffset = 1;
  double _currentExposureOffset = 0.0;
  late AnimationController _exposureModeControlRowAnimationController;
  late Animation<double> _exposureModeControlRowAnimation;
  String output = '';

  @override
  void initState() {
    super.initState();
    initializeCamera().then((_) {
      startCameraPreview();
    });
    startListening();
    ///
    _exposureModeControlRowAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _exposureModeControlRowAnimation = CurvedAnimation(
      parent: _exposureModeControlRowAnimationController,
      curve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    stopCameraPreview();
    _cameraController.dispose();
    _exposureModeControlRowAnimationController.dispose();
    super.dispose();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController.initialize();
  }

  void startCameraPreview() {
    _cameraImageSubscription = _cameraController.startImageStream((CameraImage image) {
      // Calculate the average grayscale value of the image
      final grayscaleValue = calculateAverageGrayscale(image);

      // Calculate the average brightness value of the image
      final brightnessValue = calculateAverageBrightness(image);

      // Upd ate the grayscale value and brightness value, and refresh the UI
      setState(() {
        _grayscaleValue = grayscaleValue;
        _brightnessValue = brightnessValue;

        ///VIKAS
        _isLowLight = grayscaleValue < 235;
        _isBadLighting = checkBadLighting(grayscaleValue, brightnessValue);
      });
    }) as StreamSubscription<CameraImage>?;
  }

  void stopCameraPreview() {
    _cameraImageSubscription?.cancel();
    _cameraController.stopImageStream();
  }

  void startRecording() async {
    await _cameraController.startVideoRecording();
  }

  void stopRecording() async {
    await _cameraController.stopVideoRecording();
  }

  double calculateAverageGrayscale(CameraImage image) {
    double sum = 0;
    int totalPixels = image.width * image.height;

    for (var plane in image.planes) {
      final bytes = plane.bytes;
      for (int i = 0; i < bytes.length; i++) {
        sum += bytes[i];
      }
    }

    return sum / totalPixels;
  }

  double calculateAverageBrightness(CameraImage image) {
    double sum = 0;
    int totalPixels = image.width * image.height;

    for (var plane in image.planes) {
      final bytes = plane.bytes;
      for (int i = 0; i < bytes.length; i += plane.bytesPerPixel!) {
        final pixel = bytes[i];
        sum += (0.2126 * Color(pixel).red +
            0.7152 * Color(pixel).green +
            0.0722 * Color(pixel).blue);
      }
    }

    return sum / totalPixels;
  }

  void onData(int luxValue) async {
    setState(() {
      _luxString = "$luxValue";
      _isLowLight = luxValue < 10;
    });
  }

  void stopListening() {
    _subscription?.cancel();
  }

  void startListening() {
    _light = Light();
    try {
      _subscription = _light?.lightSensorStream.listen(onData);
    } on LightException catch (exception) {
      print(exception);
    }
  }


  ///VIKAS
  bool checkBadLighting(double grayscaleValue, double brightnessValue) {
    if (grayscaleValue < 230 && brightnessValue < 11) {
      return true;
    } else if (grayscaleValue < 250 && brightnessValue < 20) {
      return true;
    } else if (grayscaleValue > 280 && brightnessValue > 25) {
      return true;
    } else {
      return false;
    }
  }
  ///

  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Container();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Preview'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: _cameraController.value.aspectRatio,
                  child: CameraPreview(_cameraController),
                ),
              ),
              ///EXPOSURE ICON POSITIONED BELOW
              Container(padding: EdgeInsets.all(16.0),child: _modeControlRowWidget()),

              Container(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Grayscale: ${_grayscaleValue.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18.0),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Brightness: ${_brightnessValue.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18.0),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16.0),
                child: Text('Lux value: $_luxString\n'),
              ),
            ],
          ),
          if (_isLowLight || _isBadLighting)
            Container(
              alignment: Alignment.center,
              child: const Text(
                'ADJUST LIGHTING',
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: startRecording,
        child: Icon(Icons.videocam),
      ),
    );
  }


  ///EXPOSURE
  Widget _modeControlRowWidget() {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            // The exposure and focus mode are currently not supported on the web.
            ...!kIsWeb
                ? <Widget>[
              IconButton(
                icon: const Icon(Icons.exposure),
                color: Colors.blue,
                onPressed: _cameraController != null
                    ? onExposureModeButtonPressed
                    : null,
              ),
            ]
                : <Widget>[],
          ],
        ),
        _exposureModeControlRowWidget(),
        SizedBox(height: 10,),
        Text(
          output,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        )
      ],
    );
  }

  Widget _exposureModeControlRowWidget() {
    return SizeTransition(
      sizeFactor: _exposureModeControlRowAnimation,
      child: ClipRect(
        child: Container(
          color: Colors.transparent,
          child: Column(
            children: <Widget>[
              const Center(
                child: Text('Exposure Mode',style: TextStyle(color: Colors.white),),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  TextButton(
                    onPressed: _cameraController != null
                        ? () =>{ _cameraController!.setExposureOffset(0.0),_currentExposureOffset=0.0}
                        : null,
                    child: const Text('DEFAULT'),
                  ),
                ],
              ),
              const Center(
                child: Text('Move to se t Exposure',style: TextStyle(color: Colors.white),),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Text(_minAvailableExposureOffset.toString(),style: TextStyle(color: Colors.white),),
                  Slider(
                    value: _currentExposureOffset,
                    min: _minAvailableExposureOffset,
                    max: _maxAvailableExposureOffset,
                    label: _currentExposureOffset.toString(),
                    onChanged: _minAvailableExposureOffset ==
                        _maxAvailableExposureOffset
                        ? null
                        : setExposureOffset,
                  ),
                  Text(_maxAvailableExposureOffset.toString(),style: TextStyle(color: Colors.white),),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Future<void> setExposureOffset(double offset) async {
    if (_cameraController == null) {
      return;
    }

    setState(() {
      _currentExposureOffset = offset;
    });
    try {
      offset = await _cameraController!.setExposureOffset(offset);
    } on CameraException catch (e) {
      //  _showCameraException(e);
      rethrow;
    }
  }
  void onExposureModeButtonPressed() {
    if (_exposureModeControlRowAnimationController.value == 1) {
      _exposureModeControlRowAnimationController.reverse();
    } else {
      _exposureModeControlRowAnimationController.forward();
    }
  }

}