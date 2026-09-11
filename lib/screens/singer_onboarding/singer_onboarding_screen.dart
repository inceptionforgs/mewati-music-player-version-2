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

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SingerOnboardingProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        title: const Text('Singer Onboarding Portal'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
          padding: const EdgeInsets.all(16),
          child: p.submitted
              ? const Center(
                  child: Text(
                    'Permission mil gayi. Review pending hai.\n'
                    'Gaane is form se nahi jaate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Step ${p.step + 1} / 4',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 8),
                    if (p.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          p.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    Expanded(child: _step(context, p)),
                    const SizedBox(height: 12),
                    if (p.submitting)
                      const Center(child: CircularProgressIndicator())
                    else
                      _nav(context, p),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _step(BuildContext context, SingerOnboardingProvider p) {
    switch (p.step) {
      case 0:
        return _BasicStep(p: p);
      case 1:
        return IdCaptureStep(
          hasCapture: p.idJpeg != null,
          onCaptured: (bytes) => p.setIdJpeg(Uint8List.fromList(bytes)),
        );
      case 2:
        return LivenessStep(
          done: p.selfieJpeg != null,
          onVerified: (bytes) => p.setSelfieJpeg(Uint8List.fromList(bytes)),
        );
      default:
        return _TermsStep(p: p);
    }
  }

  Widget _nav(BuildContext context, SingerOnboardingProvider p) {
    if (p.step < 3) {
      final ok = p.step == 0
          ? p.canGoStep2
          : p.step == 1
              ? p.canGoStep3
              : p.canGoStep4;
      return ElevatedButton(
        onPressed: ok ? p.next : null,
        child: const Text('Aage'),
      );
    }
    return ElevatedButton(
      onPressed: p.canSubmit ? () => p.submit() : null,
      child: const Text('Submit'),
    );
  }
}

class _BasicStep extends StatelessWidget {
  final SingerOnboardingProvider p;
  const _BasicStep({required this.p});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text('Basic Info',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        const SizedBox(height: 16),
        TextField(
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
          onChanged: p.setName,
        ),
        const SizedBox(height: 12),
        TextField(
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'Mobile Number',
            labelStyle: TextStyle(color: Colors.white70),
            counterStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
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
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 24) {
                p.markTermsReadToEnd();
              }
              return false;
            },
            child: SingleChildScrollView(
              child: Text(
                SingerTerms.text,
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!p.termsReadToEnd)
          const Text(
            'Pehle poori terms end tak padho.',
            style: TextStyle(color: Colors.orangeAccent),
          ),
        CheckboxListTile(
          value: p.termsAccepted,
          onChanged: p.termsReadToEnd
              ? (v) => p.setTermsAccepted(v ?? false)
              : null,
          title: const Text(
            'Main sehmat hu',
            style: TextStyle(color: Colors.white),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const Text(
          'Aapka consent aapke device/samay ki jaankari ke saath securely record kiya jayega.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}