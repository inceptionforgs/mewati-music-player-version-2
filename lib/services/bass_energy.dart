import 'package:flutter/services.dart';

class BassEnergy {
  BassEnergy._();

  static const EventChannel _events = EventChannel('mewati.sound/bassEnergy');

  static Stream<double> get stream => _events
      .receiveBroadcastStream()
      .map((e) => (e as num).toDouble().clamp(0.0, 1.0));
}