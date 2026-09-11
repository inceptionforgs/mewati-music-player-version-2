import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class IdCaptureStep extends StatefulWidget {
  final void Function(List<int> jpeg) onCaptured;
  final bool hasCapture;

  const IdCaptureStep({
    super.key,
    required this.onCaptured,
    required this.hasCapture,
  });

  @override
  State<IdCaptureStep> createState() => _IdCaptureStepState();
}

class _IdCaptureStepState extends State<IdCaptureStep> {
  CameraController? _controller;
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
      if (mounted) setState(() => _error = 'Camera permission chahiye.');
      return;
    }
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _error = 'Camera nahi mili.');
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
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera khul nahi payi.');
    }
  }

  Future<void> _snap() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      widget.onCaptured(bytes);
    } catch (_) {
      if (mounted) setState(() => _error = 'Photo nahi khichi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        const Text(
          'ID document ki LIVE photo lo. Gallery se upload nahi ho sakta.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CameraPreview(c),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.hasCapture)
          const Text('ID photo ready.', style: TextStyle(color: Color(0xFF7DFFB3))),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _busy ? null : _snap,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt),
          label: Text(widget.hasCapture ? 'Dobara click karo' : 'ID photo click karo'),
        ),
      ],
    );
  }
}