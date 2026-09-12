import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/shutter_sound.dart';

class IdCaptureStep extends StatefulWidget {
  final void Function(List<int> jpeg) onCaptured;
  final VoidCallback onCleared;
  final bool hasCapture;

  const IdCaptureStep({
    super.key,
    required this.onCaptured,
    required this.onCleared,
    required this.hasCapture,
  });

  @override
  State<IdCaptureStep> createState() => _IdCaptureStepState();
}

class _IdCaptureStepState extends State<IdCaptureStep> {
  static const _accent = Color(0xFF7CB342);

  CameraController? _controller;
  Uint8List? _preview;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _error = 'Camera permission is required.');
      }
      return;
    }
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _error = 'No camera found.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the camera.');
    }
  }

  Future<void> _snap() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      await ShutterSound.play();
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      widget.onCaptured(bytes);
      if (mounted) setState(() => _preview = bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not take the photo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retake() {
    widget.onCleared();
    setState(() {
      _preview = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
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
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _preview != null
                ? Image.memory(_preview!, fit: BoxFit.cover, width: double.infinity)
                : CameraPreview(c),
          ),
        ),
        const SizedBox(height: 14),
        if (_preview != null)
          const Text(
            'Check the photo. Retake if the ID is unclear.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9AA3AB), fontSize: 13),
          )
        else
          const Text(
            'Hold the ID inside the frame. Live camera only — gallery is off.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9AA3AB), fontSize: 13),
          ),
        const SizedBox(height: 12),
        if (_preview != null)
          OutlinedButton.icon(
            onPressed: _retake,
            icon: const Icon(Icons.refresh),
            label: const Text('Retake photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(color: _accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else
          FilledButton.icon(
            onPressed: _busy ? null : _snap,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined),
            label: const Text('Capture ID'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}