import 'package:jetleaf_lang/lang.dart';

import 'memory_reading.dart';

/// {@template default_memory_reading}
/// A concrete implementation of [AbstractMemoryReading] representing
/// a single memory snapshot of the application at a given point in time.
///
/// `DefaultMemoryReading` captures essential metrics for monitoring
/// and analytics, including:
/// - The exact time the reading was taken ([_timestamp])  
/// - The memory usage in megabytes ([_memoryMB])  
/// - The uptime of the application at the moment of the reading ([_uptime])
///
/// This class is immutable and is intended to be used for:
/// - Collecting historical memory usage data
/// - Feeding into [MemoryAnalytics] computations
/// - Logging or diagnostics
///
/// ---
/// ## Example
/// ```dart
/// final reading = DefaultMemoryReading(
///   timestamp: DateTime.now(),
///   memoryMB: 123.45,
///   uptime: Duration(minutes: 5),
/// );
///
/// print(reading.getMemoryInMegaByteString()); // "123.45MB"
/// print(reading.getCreatedAt()); // Timestamp of creation
/// print(reading.getUptime()); // Duration since app start
/// ```
/// {@endtemplate}
final class DefaultMemoryReading extends AbstractMemoryReading {
  /// The timestamp when this memory reading was captured.
  ///
  /// This marks the exact moment the memory usage measurement was taken.
  final DateTime _timestamp;

  /// The memory usage in megabytes at the time of this reading.
  ///
  /// Used for analytics and monitoring. Represented as a [double] for
  /// precision, and converted to [Double] when returned via
  /// [getMemoryInMegaByte].
  final double _memoryMB;

  /// The uptime of the application at the time of this memory reading.
  ///
  /// Typically used for calculating trends or correlating memory
  /// consumption with runtime duration.
  final Duration _uptime;

  /// Creates a new [DefaultMemoryReading].
  ///
  /// If [timestamp] is not provided, the current system time is used.
  /// [memoryMB] defaults to `0.0` and [uptime] defaults to `Duration.zero`.
  /// 
  /// {@macro default_memory_reading}
  DefaultMemoryReading({DateTime? timestamp, double memoryMB = 0.0, Duration uptime = Duration.zero})
    : _memoryMB = memoryMB, _timestamp = timestamp ?? DateTime.now(), _uptime = uptime;

  @override
  DateTime getCreatedAt() => _timestamp;

  @override
  Double getMemoryInMegaByte() => Double(_memoryMB);

  @override
  Duration getUptime() => _uptime;

  @override
  List<Object?> equalizedProperties() => [_memoryMB, _timestamp, _uptime];

  @override
  String toString() => 'MemoryReading(${getCreatedAt().toIso8601String()}, ${getMemoryInMegaByteString()}, uptime: ${getUptime()})';
}