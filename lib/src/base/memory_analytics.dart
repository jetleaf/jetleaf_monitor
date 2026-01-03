import 'package:jetleaf_lang/lang.dart';

import 'memory_reading.dart';

/// {@template memory_analytics}
/// Represents a computed analytical view over a collection of
/// [MemoryReading] snapshots taken during a defined observation window.
///
/// The [MemoryAnalytics] interface provides essential aggregate metrics
/// derived from raw memory readings, enabling JetLeaf diagnostics,
/// monitoring dashboards, and adaptive resource managers to understand
/// memory behavior over time.
///
/// Implementations are expected to:
/// - Consume a chronological list of [MemoryReading] instances  
/// - Compute derived statistical values  
/// - Preserve the associated time window  
/// - Provide consistent JSON serialization via [ToJsonFactory]  
///
/// ---
/// ## 📈 Metrics Provided
///
/// The analytics expose the following computed values:
///
/// - **Minimum Memory (MB)**  
///   The lowest recorded memory usage inside the time window.
///
/// - **Maximum Memory (MB)**  
///   The highest recorded memory usage.
///
/// - **Average Memory (MB)**  
///   Statistical mean across all readings.
///
/// - **Current Memory (MB)**  
///   Typically the most recent reading's memory usage.
///
/// - **Time Window**  
///   A `Duration` indicating the span of time covered by the readings
///   (e.g., last 1 minute, last 15 minutes, last 24 hours).
///
/// - **Raw Readings**  
///   The underlying list of [MemoryReading] instances used to compute
///   the aggregated values. These must be returned in the order expected
///   by the implementation (usually chronological).
///
/// ---
/// ## 🔍 Purpose & Use Cases
///
/// `MemoryAnalytics` forms the backbone of JetLeaf’s runtime visibility.
/// It is commonly consumed by:
///
/// - **Diagnostic Endpoints** (exposed through REST or CLI)  
/// - **Dashboard Telemetry UIs**  
/// - **Adaptive Resource Managers**  
/// - **Alert Systems** (e.g., "memory spike detected")  
///
/// It allows the framework to analyze trends such as:
/// - Memory spikes  
/// - Slow leaks  
/// - Average usage over time  
/// - Stability under load  
///
/// ---
/// ## 🧪 Example Implementation
///
/// ```dart
/// final class SimpleMemoryAnalytics implements MemoryAnalytics {
///   final List<MemoryReading> _readings;
///   final Duration _window;
///
///   SimpleMemoryAnalytics(this._readings, this._window);
///
///   @override
///   Double getMinimumMemoryInMegaByte() =>
///       Double(_readings.map((r) => r.getMemoryInMegaByte().value).reduce(min));
///
///   @override
///   Double getMaximumMemoryInMegaByte() =>
///       Double(_readings.map((r) => r.getMemoryInMegaByte().value).reduce(max));
///
///   @override
///   Double getAverageMemoryInMegaByte() {
///     final values = _readings.map((r) => r.getMemoryInMegaByte().value);
///     return Double(values.reduce((a, b) => a + b) / values.length);
///   }
///
///   @override
///   Double getCurrentMemoryInMegaByte() =>
///       _readings.last.getMemoryInMegaByte();
///
///   @override
///   Duration getTimeWindow() => _window;
///
///   @override
///   List<MemoryReading> getReadings() => List.unmodifiable(_readings);
///
///   @override
///   Map<String, Object> toJson() => {
///     'windowMs': getTimeWindow().inMilliseconds,
///     'minMB': getMinimumMemoryInMegaByte().value,
///     'maxMB': getMaximumMemoryInMegaByte().value,
///     'avgMB': getAverageMemoryInMegaByte().value,
///     'currentMB': getCurrentMemoryInMegaByte().value,
///   };
/// }
/// ```
///
/// ---
/// ## 📝 Design Notes
///
/// - Analytics should be computed **deterministically** based on the
///   underlying readings.  
/// - If readings are empty, implementations must document how they behave
///   (throw, return zeros, etc.).  
/// - Values are represented using JetLeaf's [`Double`] abstraction,
///   ensuring consistency with framework math utilities.  
/// - Classes must mix in [EqualsAndHashCode] to provide reliable equality
///   semantics for unit tests and state comparison.  
/// - Implementations should not mutate the returned list from
///   [getReadings]; prefer returning an unmodifiable view.
///
/// ---
/// ## Related Components
/// - [MemoryReading] — Raw memory snapshots  
/// - `MemoryMonitor` — Produces readings and orchestrates analytics  
/// - [ToJsonFactory] — Required for exporting analytics through diagnostics  
/// - [EqualsAndHashCode] — Ensures predictable structural comparison  
///
/// {@endtemplate}
abstract interface class MemoryAnalytics with EqualsAndHashCode {
  /// Returns the lowest recorded memory usage (in megabytes) within
  /// the analytics time window.
  ///
  /// Implementations must compute this value from the underlying
  /// [MemoryReading] list, typically by scanning the full set of
  /// readings and returning the minimum `Double` value.
  ///
  /// ### Example
  /// ```dart
  /// print('Min MB: ${analytics.getMinimumMemoryInMegaByte()}');
  /// ```
  Double getMinimumMemoryInMegaByte();

  /// Returns the highest recorded memory usage (in megabytes) observed
  /// during the analytics time window.
  ///
  /// Implementations derive this from the complete list of
  /// [MemoryReading] snapshots, ensuring consistency even when readings
  /// span multiple sampling intervals.
  ///
  /// ### Example
  /// ```dart
  /// print('Max MB: ${analytics.getMaximumMemoryInMegaByte()}');
  /// ```
  Double getMaximumMemoryInMegaByte();

  /// Computes and returns the average memory usage (in megabytes)
  /// across all [MemoryReading] snapshots in the analytics window.
  ///
  /// Implementations should calculate the statistical mean using the
  /// raw values extracted from each reading. If no readings exist,
  /// behavior must be documented by the implementation.
  ///
  /// ### Example
  /// ```dart
  /// print('Avg MB: ${analytics.getAverageMemoryInMegaByte()}');
  /// ```
  Double getAverageMemoryInMegaByte();

  /// Returns the most recently recorded memory usage (in megabytes).
  ///
  /// This value typically corresponds to the final (chronologically
  /// latest) [MemoryReading], representing the system’s current
  /// memory state at the end of the observation window.
  ///
  /// ### Example
  /// ```dart
  /// print('Current MB: ${analytics.getCurrentMemoryInMegaByte()}');
  /// ```
  Double getCurrentMemoryInMegaByte();

  /// Returns the total time span represented by this analytic view.
  ///
  /// The returned [Duration] corresponds to the observation window over
  /// which the readings were collected (e.g., last 60 seconds,
  /// last 1 hour). This duration is essential for comparing analytics
  /// across sampling configurations.
  ///
  /// ### Example
  /// ```dart
  /// print('Window: ${analytics.getTimeWindow().inSeconds}s');
  /// ```
  Duration getTimeWindow();

  /// Returns the underlying list of [MemoryReading] snapshots that
  /// were used to compute all aggregated metrics.
  ///
  /// Implementations should return the readings in deterministic order
  /// (usually chronological) and must not expose a mutable reference to
  /// internal state—prefer an unmodifiable view.
  ///
  /// ### Example
  /// ```dart
  /// for (final r in analytics.getReadings()) {
  ///   print(r.getMemoryInMegaByte());
  /// }
  /// ```
  List<MemoryReading> getReadings();

  /// Converts this object into a JSON-compatible map.
  ///
  /// The returned structure must be compatible with standard JSON encoders.
  /// It should not contain:
  /// - Arbitrary objects that cannot be serialized  
  /// - Cyclic references  
  /// - Non-primitive types unless explicitly supported  
  ///
  /// ### Returns
  /// A `Map<String, Object>` containing all serializable fields that represent
  /// this object's state.
  ///
  /// ### Example
  /// ```dart
  /// final json = myObject.toJson();
  /// print(jsonEncode(json));
  /// ```
  Map<String, Object> toJson();
}

/// {@template abstract_memory_analytics}
/// A convenience base class for [MemoryAnalytics] implementations that provides
/// derived metrics commonly needed by diagnostics, dashboards, and monitoring
/// subsystems.
///
/// `AbstractMemoryAnalytics` builds on top of the core metrics defined by
/// [MemoryAnalytics] and exposes additional **delta** and **range**
/// computations:
///
/// - **Minimum Delta** – difference between current memory and the minimum
///   recorded memory
/// - **Maximum Delta** – difference between current memory and the maximum
///   recorded memory
/// - **Range** – full span between maximum and minimum memory values
///
/// These values are useful when analyzing memory variability, detecting
/// abnormal spikes, or visualizing deviation from typical baseline memory
/// consumption.
///
/// ### Intended Usage
/// - Extend this class when implementing custom analytics engines  
/// - Override only the base [MemoryAnalytics] methods; delta computations
///   are automatically derived  
/// - Consumers such as dashboards and adaptive resource controllers may rely
///   on these helpers to avoid re-implementing their own delta math
///
/// ### Example
/// ```dart
/// final analytics = SimpleMemoryAnalytics(readings, Duration(minutes: 1));
///
/// print('Min Δ: ${analytics.getMinimumDelta()}');
/// print('Max Δ: ${analytics.getMaximumDelta()}');
/// print('Range: ${analytics.getRange()}');
/// ```
///
/// ### Notes
/// - All returned values are computed using JetLeaf’s [`Double`] abstraction  
/// - Implementations must guarantee that the backing [MemoryAnalytics] methods  
///   return consistent and valid values  
/// - No internal caching is performed; deltas are always computed on demand  
///
/// {@endtemplate}
abstract class AbstractMemoryAnalytics implements MemoryAnalytics {
  /// Returns the difference between the current memory usage and the
  /// minimum recorded memory value.
  ///
  /// This metric indicates how far the system has risen from its lowest point
  /// within the analytics window.
  ///
  /// ### Example
  /// ```dart
  /// final delta = analytics.getMinimumDelta();
  /// print('Above minimum by: ${delta.value} MB');
  /// ```
  Double getMinimumDelta() => getCurrentMemoryInMegaByte() - getMinimumMemoryInMegaByte();

  /// Returns the difference between the current memory usage and the
  /// maximum recorded memory value.
  ///
  /// This value is typically **zero or negative** unless the system is
  /// currently exceeding its previous high-water mark.
  ///
  /// ### Example
  /// ```dart
  /// final delta = analytics.getMaximumDelta();
  /// if (delta.value < 0) {
  ///   print('New memory peak detected.');
  /// }
  /// ```
  Double getMaximumDelta() => getCurrentMemoryInMegaByte() - getMaximumMemoryInMegaByte();

  /// Returns the total memory amplitude (range) recorded within the
  /// analytics window.
  ///
  /// The range is computed as:
  /// ```
  /// max(memory) - min(memory)
  /// ```
  ///
  /// This metric is frequently used to evaluate stability or volatility of
  /// memory usage over time.
  ///
  /// ### Example
  /// ```dart
  /// final range = analytics.getRange();
  /// print('Window memory range: ${range.value} MB');
  /// ```
  Double getRange() => getMaximumMemoryInMegaByte() - getMinimumMemoryInMegaByte();

  /// Returns the maximum delta as a formatted string in megabytes.
  ///
  /// The returned string is rounded to two decimal places and
  /// suffixed with "MB" for clarity.
  ///
  /// **Example:**
  /// ```dart
  /// print(reading.getMaximumDeltaString()); // → "123.45MB"
  /// ```
  String getMaximumDeltaString() => "${getMaximumDelta().value.toStringAsFixed(2)}MB";

  /// Returns the minimum delta as a formatted string in megabytes.
  ///
  /// The returned string is rounded to two decimal places and
  /// suffixed with "MB" for clarity.
  ///
  /// **Example:**
  /// ```dart
  /// print(reading.getMinimumDeltaString()); // → "123.45MB"
  /// ```
  String getMinimumDeltaString() => "${getMinimumDelta().value.toStringAsFixed(2)}MB";

  /// Returns the range as a formatted string in megabytes.
  ///
  /// The returned string is rounded to two decimal places and
  /// suffixed with "MB" for clarity.
  ///
  /// **Example:**
  /// ```dart
  /// print(reading.getRangeString()); // → "123.45MB"
  /// ```
  String getRangeString() => "${getRange().value.toStringAsFixed(2)}MB";

  /// Returns the maximum memory usage as a formatted string in megabytes.
  ///
  /// The returned string is rounded to two decimal places and
  /// suffixed with "MB" for clarity.
  ///
  /// **Example:**
  /// ```dart
  /// print(reading.getMaximumMemoryInMegaByteString()); // → "123.45MB"
  /// ```
  String getMaximumMemoryInMegaByteString() => "${getMaximumMemoryInMegaByte().value.toStringAsFixed(2)}MB";

  /// Returns the minimum memory usage as a formatted string in megabytes.
  ///
  /// The returned string is rounded to two decimal places and
  /// suffixed with "MB" for clarity.
  ///
  /// **Example:**
  /// ```dart
  /// print(reading.getMinimumMemoryInMegaByteString()); // → "123.45MB"
  /// ```
  String getMinimumMemoryInMegaByteString() => "${getMinimumMemoryInMegaByte().value.toStringAsFixed(2)}MB";

  /// Returns the average memory usage as a formatted string in megabytes.
  ///
  /// The returned string is rounded to two decimal places and
  /// suffixed with "MB" for clarity.
  ///
  /// **Example:**
  /// ```dart
  /// print(reading.getAverageMemoryInMegaByteString()); // → "123.45MB"
  /// ```
  String getAverageMemoryInMegaByteString() => "${getAverageMemoryInMegaByte().value.toStringAsFixed(2)}MB";

  /// Returns the current memory usage as a formatted string in megabytes.
  ///
  /// The returned string is rounded to two decimal places and
  /// suffixed with "MB" for clarity.
  ///
  /// **Example:**
  /// ```dart
  /// print(reading.getCurrentMemoryInMegaByteString()); // → "123.45MB"
  /// ```
  String getCurrentMemoryInMegaByteString() => "${getCurrentMemoryInMegaByte().value.toStringAsFixed(2)}MB";

  @override
  Map<String, Object> toJson() => {
    "time_window": getTimeWindow().inMinutes,
    "min_memory_in_mb": getMinimumMemoryInMegaByteString(),
    "max_memory_in_mb": getMaximumMemoryInMegaByteString(),
    "avg_memory_in_mb": getAverageMemoryInMegaByteString(),
    "current_memory_in_mb": getCurrentMemoryInMegaByteString(),
    "maximum_delta_in_mb": getMaximumDeltaString(),
    "minimum_delta_in_mb": getMinimumDeltaString(),
    "range_in_mb": getRangeString()
  };
}