import 'package:flutter/services.dart';

class AndroidAiTelemetrySnapshot {
  final int? sdkInt;
  final int? thermalStatus;
  final double? batteryPercent;
  final int? batteryCurrentMicroAmps;
  final int? batteryChargeCounterMicroAh;
  final int? batteryEnergyCounterNanoWh;
  final int? batteryTemperatureTenthsC;
  final int? batteryVoltageMv;
  final int? batteryPlugged;

  const AndroidAiTelemetrySnapshot({
    this.sdkInt,
    this.thermalStatus,
    this.batteryPercent,
    this.batteryCurrentMicroAmps,
    this.batteryChargeCounterMicroAh,
    this.batteryEnergyCounterNanoWh,
    this.batteryTemperatureTenthsC,
    this.batteryVoltageMv,
    this.batteryPlugged,
  });

  factory AndroidAiTelemetrySnapshot.fromMap(Map<Object?, Object?> map) {
    int? integer(String key) => (map[key] as num?)?.toInt();
    double? decimal(String key) => (map[key] as num?)?.toDouble();

    return AndroidAiTelemetrySnapshot(
      sdkInt: integer('sdkInt'),
      thermalStatus: integer('thermalStatus'),
      batteryPercent: decimal('batteryPercent'),
      batteryCurrentMicroAmps: integer('batteryCurrentMicroAmps'),
      batteryChargeCounterMicroAh: integer('batteryChargeCounterMicroAh'),
      batteryEnergyCounterNanoWh: integer('batteryEnergyCounterNanoWh'),
      batteryTemperatureTenthsC: integer('batteryTemperatureTenthsC'),
      batteryVoltageMv: integer('batteryVoltageMv'),
      batteryPlugged: integer('batteryPlugged'),
    );
  }

  Map<String, dynamic> toJson() => {
        'sdkInt': sdkInt,
        'thermalStatus': thermalStatus,
        'batteryPercent': batteryPercent,
        'batteryCurrentMicroAmps': batteryCurrentMicroAmps,
        'batteryChargeCounterMicroAh': batteryChargeCounterMicroAh,
        'batteryEnergyCounterNanoWh': batteryEnergyCounterNanoWh,
        'batteryTemperatureTenthsC': batteryTemperatureTenthsC,
        'batteryVoltageMv': batteryVoltageMv,
        'batteryPlugged': batteryPlugged,
      };
}

class AndroidAiTelemetryService {
  AndroidAiTelemetryService._();

  static final instance = AndroidAiTelemetryService._();

  static const _channel = MethodChannel(
    'com.meteor.kikoeruflutter/ai_benchmark',
  );

  Future<AndroidAiTelemetrySnapshot?> snapshot() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('getTelemetry');
      if (raw is! Map) return null;
      return AndroidAiTelemetrySnapshot.fromMap(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
