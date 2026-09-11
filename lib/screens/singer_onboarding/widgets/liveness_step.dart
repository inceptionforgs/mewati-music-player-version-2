import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

class LivenessStep extends StatefulWidget {
  final void Function(List<int> jpeg) onVerified;
  final bool done;

  const LivenessStep({
    super.key,
    required this.onVerified,
    required this.done,
  });

  @override
  State<LivenessStep> createState() => _LivenessStepState();
}

class _LivenessStepState extends State<LivenessStep> {
  CameraController? _controller;
  FaceDetector? _detector;
  String? _error;
  bool _busy = false;
  bool _streaming = false;
  int _frame = 0;
  bool _leftDone = false;
  bool _rightDone = false;
  String _hint = 'apna sar halka sa LEFT ghumao';

  static const _turn = 16.0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _error = 'Camera permission chahiye.');
      return;
    }
    try {
      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: false,
          enableLandmarks: false,
          enableContours: false,
          enableTracking: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _error = 'Camera nahi mili.');
        return;
      }
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Front camera / face check start nahi hua.');
      }
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _leftDone && _rightDone) return;
    _frame++;
    if (_frame % 3 != 0) return;
    final detector = _detector;
    final cam = _controller;
    if (detector == null || cam == null) return;
    _busy = true;
    try {
      final input = _toInputImage(image, cam.description);
      if (input == null) return;
      final faces = await detector.processImage(input);
      if (faces.isEmpty || !mounted) return;
      final y = faces.first.headEulerAngleY;
      if (y == null) return;
      var changed = false;
      if (!_leftDone && y <= -_turn) {
        _leftDone = true;
        _hint = 'ab sar halka sa RIGHT ghumao';
        changed = true;
      } else if (_leftDone && !_rightDone && y >= _turn) {
        _rightDone = true;
        _hint = 'Verify ho gaya. Selfie le rahe hain…';
        changed = true;
      }
      if (changed && mounted) setState(() {});
      if (_leftDone && _rightDone) {
        await _captureStill();
      }
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription desc) {
    try {
      final nv21 = _yuv420ToNv21(image);
      final rotation = InputImageRotationValue.fromRawValue(desc.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      return InputImage.fromBytes(
        bytes: nv21,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final ySize = width * height;
    final out = Uint8List(ySize + ySize ~/ 2);
    var outI = 0;
    for (var row = 0; row < height; row++) {
      final start = row * yPlane.bytesPerRow;
      out.setRange(outI, outI + width, yPlane.bytes.sublist(start, start + width));
      outI += width;
    }
    for (var row = 0; row < height ~/ 2; row++) {
      final vRow = row * vPlane.bytesPerRow;
      final uRow = row * uPlane.bytesPerRow;
      for (var col = 0; col < width ~/ 2; col++) {
        final ui = uRow + col * (uPlane.bytesPerPixel ?? 1);
        final vi = vRow + col * (vPlane.bytesPerPixel ?? 1);
        out[outI++] = vPlane.bytes[vi];
        out[outI++] = uPlane.bytes[ui];
      }
    }
    return out;
  }

  Future<void> _captureStill() async {
    final c = _controller;
    if (c == null) return;
    try {
      if (_streaming) {
        await c.stopImageStream();
        _streaming = false;
      }
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) widget.onVerified(bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'Selfie capture fail.');
    }
  }

  @override
  void dispose() {
    final c = _controller;
    if (c != null && _streaming) {
      c.stopImageStream();
    }
    c?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _controller == null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Text(_hint, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          'Left: ${_leftDone ? "OK" : "…"}    Right: ${_rightDone ? "OK" : "…"}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CameraPreview(c),
          ),
        ),
        if (widget.done)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Liveness selfie ready.',
                style: TextStyle(color: Color(0xFF7DFFB3))),
          ),
      ],
    );
  }
}