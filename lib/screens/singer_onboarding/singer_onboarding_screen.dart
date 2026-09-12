import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/singer_terms.dart';
import '../../providers/singer_onboarding_provider.dart';
import 'widgets/id_capture_step.dart';
import 'widgets/liveness_step.dart';

class SingerOnboardingScreen extends StatelessWidget {
  const SingerOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SingerOnboardingProvider(),
      child: const _SingerOnboardingBody(),
    );
  }
}

class _SingerOnboardingBody extends StatelessWidget {
  const _SingerOnboardingBody();

  static const _bg = Color(0xFF101214);
  static const _accent = Color(0xFF7CB342);
  static const _muted = Color(0xFF9AA3AB);

  static const _titles = [
    'Your details',
    'Liveness check',
    'Identity document',
    'Permission terms',
  ];

  static const _subtitles = [
    'Name and mobile as they should appear on the record.',
    'Blink twice so we know a live person is in front of the camera.',
    'Photograph a government ID. Check the preview and retake if needed.',
    'Review the terms, then confirm your agreement below.',
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SingerOnboardingProvider>();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Singer permission',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: p.submitting
              ? null
              : () {
                  if (p.step == 0 || p.submitted) {
                    Navigator.of(context).maybePop();
                  } else {
                    p.back();
                  }
                },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: p.submitted ? const _DoneCard() : _form(p),
        ),
      ),
    );
  }

  Widget _form(SingerOnboardingProvider p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (p.step + 1) / 4,
            minHeight: 4,
            color: _accent,
            backgroundColor: Colors.white12,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'STEP ${p.step + 1} OF 4',
          style: const TextStyle(
            color: _accent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _titles[p.step],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _subtitles[p.step],
          style: const TextStyle(color: _muted, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 18),
        if (p.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              p.errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
        Expanded(child: _step(p)),
        const SizedBox(height: 12),
        if (p.submitting)
          const Center(child: CircularProgressIndicator(color: _accent))
        else
          _nav(p),
      ],
    );
  }

  Widget _step(SingerOnboardingProvider p) {
    switch (p.step) {
      case 0:
        return _BasicStep(p: p);
      case 1:
        return LivenessStep(
          done: p.selfieJpeg != null,
          onVerified: (bytes) => p.setSelfieJpeg(Uint8List.fromList(bytes)),
          onCleared: p.clearSelfieJpeg,
        );
      case 2:
        return IdCaptureStep(
          hasCapture: p.idJpeg != null,
          onCaptured: (bytes) => p.setIdJpeg(Uint8List.fromList(bytes)),
          onCleared: p.clearIdJpeg,
        );
      default:
        return _TermsStep(p: p);
    }
  }

  Widget _nav(SingerOnboardingProvider p) {
    final ok = p.step == 0
        ? p.canGoStep2
        : p.step == 1
            ? p.canGoStep3
            : p.step == 2
                ? p.canGoStep4
                : p.canSubmit;
    final label = p.step < 3 ? 'Continue' : 'Submit permission';
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: ok
            ? () {
                if (p.step < 3) {
                  p.next();
                } else {
                  p.submit();
                }
              }
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          disabledBackgroundColor: Colors.white12,
          foregroundColor: Colors.black,
          disabledForegroundColor: Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_outlined, color: Color(0xFF7CB342), size: 40),
              SizedBox(height: 14),
              Text(
                'Permission received',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your request is in review. This form only records consent. Songs are not uploaded from here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9AA3AB), height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BasicStep extends StatelessWidget {
  final SingerOnboardingProvider p;
  const _BasicStep({required this.p});

  InputDecoration _field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF9AA3AB)),
      hintStyle: const TextStyle(color: Colors.white24),
      filled: true,
      fillColor: const Color(0xFF1A1D20),
      counterStyle: const TextStyle(color: Colors.white38),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7CB342), width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextField(
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: _field('Full name', hint: 'As on your ID'),
          onChanged: p.setName,
        ),
        const SizedBox(height: 14),
        TextField(
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: _field('Mobile number', hint: '10-digit number'),
          onChanged: p.setMobile,
        ),
      ],
    );
  }
}

class _TermsStep extends StatelessWidget {
  final SingerOnboardingProvider p;
  const _TermsStep({required this.p});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Text(
                SingerTerms.text,
                style: const TextStyle(
                  color: Color(0xFFD5DBE0),
                  height: 1.5,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: p.termsAccepted
                  ? const Color(0xFF7CB342)
                  : Colors.white12,
            ),
          ),
          child: CheckboxListTile(
            value: p.termsAccepted,
            onChanged: (v) => p.setTermsAccepted(v ?? false),
            title: const Text(
              'I have read and agree to these Terms and Conditions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Acceptance is recorded with the time and device used for this request.',
                style: TextStyle(color: Color(0xFF9AA3AB), fontSize: 11),
              ),
            ),
            activeColor: const Color(0xFF7CB342),
            checkColor: Colors.black,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}