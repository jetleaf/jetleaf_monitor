import 'dart:collection';

import 'package:jetleaf_lang/lang.dart';

import 'memory_analytics.dart';
import 'memory_reading.dart';

/// {@template default_memory_analytics}
/// A concrete implementation of [AbstractMemoryAnalytics] that provides
/// computed memory metrics over a defined observation window.
///
/// `DefaultMemoryAnalytics` aggregates multiple [MemoryReading] snapshots
/// and exposes statistical metrics such as:
/// - Minimum memory usage (_minMemoryMB)
/// - Maximum memory usage (_maxMemoryMB)
/// - Average memory usage (_avgMemoryMB)
/// - Current memory usage (_currentMemoryMB)
///
/// It also preserves:
/// - The time window over which the readings were collected (_timeWindow)
/// - The raw list of memory readings (_readings)
///
/// This class is immutable and intended for:
/// - Feeding memory analytics into monitoring dashboards
/// - Performing trend analysis and diagnostics
/// - Serializing memory metrics for reporting
///
/// ---
/// ## Example
/// ```dart
/// final analytics = DefaultMemoryAnalytics(
///   timeWindow: Duration(minutes: 5),
///   minMemoryMB: 120.0,
///   maxMemoryMB: 450.0,
///   avgMemoryMB: 300.0,
///   currentMemoryMB: 320.0,
///   readings: memoryReadings,
/// );
///
/// print(analytics.getAverageMemoryInMegaByte()); // 300.0 MB
/// print(analytics.getTimeWindow()); // Duration(minutes: 5)
/// ```
/// {@endtemplate}
final class DefaultMemoryAnalytics extends AbstractMemoryAnalytics {
  /// The duration of the time window over which memory readings were collected.
  ///
  /// Used to contextualize metrics such as average, min, and max memory.
  final Duration _timeWindow;

  /// The minimum memory usage recorded within the time window, in megabytes.
  ///
  /// Derived from the [MemoryReading] snapshots.
  final double _minMemoryMB;

  /// The maximum memory usage recorded within the time window, in megabytes.
  ///
  /// Derived from the [MemoryReading] snapshots.
  final double _maxMemoryMB;

  /// The average memory usage computed across all readings in the window, in megabytes.
  final double _avgMemoryMB;

  /// The most recent memory usage recorded, in megabytes.
  final double _currentMemoryMB;

  /// The chronological list of memory readings used to compute analytics.
  ///
  /// Returned as an unmodifiable list to preserve immutability.
  final List<MemoryReading> _readings;

  /// {@macro default_memory_analytics}
  DefaultMemoryAnalytics({
    Duration timeWindow = Duration.zero,
    double minMemoryMB = 0.0,
    double maxMemoryMB = 0.0,
    double avgMemoryMB = 0.0,
    double currentMemoryMB = 0.0,
    List<MemoryReading>? readings,
  })  : _timeWindow = timeWindow,
        _minMemoryMB = minMemoryMB,
        _maxMemoryMB = maxMemoryMB,
        _avgMemoryMB = avgMemoryMB,
        _currentMemoryMB = currentMemoryMB,
        _readings = readings ?? const [];

  @override
  Double getAverageMemoryInMegaByte() => Double(_avgMemoryMB);

  @override
  Double getCurrentMemoryInMegaByte() => Double(_currentMemoryMB);

  @override
  Double getMaximumMemoryInMegaByte() => Double(_maxMemoryMB);

  @override
  Double getMinimumMemoryInMegaByte() => Double(_minMemoryMB);

  @override
  List<MemoryReading> getReadings() => UnmodifiableListView(_readings);

  @override
  Duration getTimeWindow() => _timeWindow;

  @override
  List<Object?> equalizedProperties() => [_avgMemoryMB, _currentMemoryMB, _maxMemoryMB, _minMemoryMB, _readings, _timeWindow];
}