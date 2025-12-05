import 'dart:collection';

import 'memory_analytics.dart';
import 'memory_reading.dart';
import 'process_information.dart';
import 'monitoring_report.dart';

/// {@template default_monitoring_report}
/// Default implementation of [MonitoringReport] that aggregates
/// system-level, memory-level, and application-level runtime data.
///
/// This report is produced by the monitoring subsystem to provide
/// a holistic snapshot of:
///
/// * **Process information** — OS details, hardware info, Dart runtime
/// * **Memory analytics** — summarized memory statistics
/// * **Memory readings** — historical sampled memory values
/// * **Application start time** — when the app or monitored component began
/// * **Total uptime** — duration of the monitored lifecycle
///
/// The values in this report are immutable and represent the state
/// at the time the report was created.
/// {@endtemplate}
final class DefaultMonitoringReport implements MonitoringReport {
  /// General process information such as OS, processors, RSS, locale,
  /// and Dart runtime details.
  final ProcessInformation _information;

  /// The timestamp indicating when the application (or monitored
  /// component) first started execution.
  final DateTime _startTime;

  /// Aggregated memory analytics including minimum/maximum/current
  /// memory consumption and any derived metrics.
  final MemoryAnalytics _analytics;

  /// Historical memory readings captured over time. Each reading
  /// represents a sampled memory measurement snapshot.
  final List<MemoryReading> _readings;

  /// Total uptime duration calculated by the monitoring subsystem,
  /// representing how long the application or target process has been
  /// running.
  final Duration _uptime;

  /// Creates an immutable monitoring report with the supplied process
  /// information, start time, memory analytics, memory history, and
  /// uptime.
  /// 
  /// {@macro default_monitoring_report}
  DefaultMonitoringReport(this._information, this._startTime, this._analytics, this._readings, this._uptime);

  @override
  List<Object?> equalizedProperties() => [_analytics, _information, _readings, _startTime, _uptime];

  @override
  DateTime getAppStartTime() => _startTime;

  @override
  MemoryAnalytics getMemoryAnalytics() => _analytics;

  @override
  List<MemoryReading> getMemoryHistory() => UnmodifiableListView(_readings);

  @override
  ProcessInformation getProcessInformation() => _information;

  @override
  Duration getTotalUptime() => _uptime;

  @override
  Map<String, Object> toJson() => {
    "app.start.time": _startTime,
    "uptime.in.milliseconds": _uptime.inMilliseconds,
    "process.information": _information.toJson(),
    "memory.analytics": _analytics.toJson(),
    "memory.readings": _readings.map((r) => r.toJson()).toList(),
  };
}