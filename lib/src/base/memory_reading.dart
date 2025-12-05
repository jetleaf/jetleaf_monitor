import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';

/// {@template memory_reading}
/// Represents a snapshot of runtime memory consumption and uptime
/// for a JetLeaf-managed process or subsystem.
///
/// The [MemoryReading] interface provides a uniform contract for reading
/// memory-related operational metrics such as:
///
/// - **Creation timestamp** of the measurement  
/// - **Memory usage** expressed in megabytes (`Double`)  
/// - **Uptime** representing the duration since the process started  
///
/// JetLeaf components such as monitor pods, diagnostic endpoints, and
/// administrative dashboards rely on this interface to retrieve consistent,
/// serializable runtime statistics.
///
/// ---
/// ## 📊 Typical Usage
///
/// Implementations of [MemoryReading] usually gather data from:
/// - System-level APIs (Dart VM memory usage, OS metrics)
/// - Application context monitors
/// - Virtualized storage or sandbox environments
///
/// JetLeaf expects these readings to be **immutable snapshots**—they represent
/// the state of the system *at the moment of measurement*.
///
/// These snapshots are also serializable since the interface extends
/// [ToJsonFactory], enabling:
///
/// - Export through diagnostic endpoints  
/// - Logging in structured formats  
/// - Integration with telemetry pipelines  
///
/// ---
/// ## 🔧 Example Implementation
/// ```dart
/// final class VmMemoryReading implements MemoryReading {
///   final DateTime _createdAt = DateTime.now();
///
///   @override
///   DateTime getCreatedAt() => _createdAt;
///
///   @override
///   Double getMemoryInMegaByte() => Double(
///     (ProcessInfo.currentRss / (1024 * 1024))
///   );
///
///   @override
///   Duration getUptime() => ProcessInfo.currentUptime;
///
///   @override
///   Map<String, Object> toJson() => {
///     'createdAt': getCreatedAt().toIso8601String(),
///     'memoryMB': getMemoryInMegaByte().value,
///     'uptimeMs': getUptime().inMilliseconds,
///   };
/// }
/// ```
///
/// ---
/// ## 🔒 Design Notes
///
/// - Readings **should not mutate** after creation; treat values as a snapshot.  
/// - Implementers must ensure `Double` comes from `jetleaf_core/core.dart`
///   and not Dart's primitive double.  
/// - Timestamps should be in UTC where possible to ensure consistency across
///   distributed diagnostics systems.  
/// - Because the interface mixes in [EqualsAndHashCode], implementations must
///   ensure consistency of equality semantics—typically comparing intrinsic
///   fields (`createdAt`, `memory`, `uptime`).  
///
/// ---
/// ## Related Components
/// - [ToJsonFactory] — Ensures readings can be serialized  
/// - [EqualsAndHashCode] — Enables deterministic comparison for testing  
///
/// {@endtemplate}
abstract interface class MemoryReading with EqualsAndHashCode implements ToJsonFactory {
  /// Timestamp representing when this memory reading snapshot was created.
  ///
  /// Implementations should generally return a UTC `DateTime` for consistency
  /// across distributed systems.
  DateTime getCreatedAt();

  /// Returns the amount of memory used by the target process or subsystem,
  /// expressed in **megabytes** as a JetLeaf [Double].
  ///
  /// Implementers are responsible for converting raw memory values such as
  /// bytes or kilobytes into megabytes.
  Double getMemoryInMegaByte();

  /// Returns the system or process uptime at the moment this reading was taken.
  ///
  /// This duration typically measures the time since:
  /// - The JetLeaf runtime started,
  /// - The hosting process initialized,
  /// - or a specific subsystem began operation.
  Duration getUptime();
}

/// {@template abstract_memory_reading}
/// A base implementation of [MemoryReading] that provides common
/// utilities for representing memory usage.
///
/// `AbstractMemoryReading` serves as a foundation for concrete memory
/// reading implementations, offering convenient string formatting
/// for memory values in megabytes.
///
/// ### Example
/// ```dart
/// final reading = MyMemoryReadingImplementation();
/// print(reading.getMemoryInMegaByteString()); // → "123.45MB"
/// ```
/// {@endtemplate}
abstract class AbstractMemoryReading implements MemoryReading {
  /// Returns the memory usage as a formatted string in megabytes.
  ///
  /// The returned string is rounded to two decimal places and
  /// suffixed with "MB" for clarity.
  ///
  /// **Example:**
  /// ```dart
  /// print(reading.getMemoryInMegaByteString()); // → "123.45MB"
  /// ```
  String getMemoryInMegaByteString() => "${getMemoryInMegaByte().value.toStringAsFixed(2)}MB";

  @override
  Map<String, Object> toJson() => {
    "created_at": getCreatedAt(),
    "memory_in_mb": getMemoryInMegaByteString(),
    "uptime": getUptime()
  };
}