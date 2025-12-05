import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';

import 'memory_analytics.dart';

/// {@template performance}
/// Represents a single tracked execution event—such as a **method call**
/// or **class instantiation**—and provides detailed performance, timing,
/// memory, and error metrics associated with that execution.
///
/// A `Performance` instance is typically created by JetLeaf’s automatic
/// tracking system, allowing diagnostic tools, analytics dashboards, and
/// profiling utilities to understand how individual operations behave at
/// runtime.
///
/// Implementations must be immutable snapshots and must serialize all
/// values deterministically via [ToJsonFactory].
///
/// ---
/// ## 📊 What `Performance` Tracks
///
/// A performance record captures:
///
/// - **Name** of the method or class being executed  
/// - **Start Time** when execution began  
/// - **End Time** when execution completed (or last updated if still running)  
/// - **Run Period** (end − start)  
/// - **IP Address** associated with the request (if applicable)  
/// - **Running State** (whether the execution is ongoing)  
/// - **Memory Analytics**, allowing analysis of memory behavior *during* execution  
/// - **Error Counts**, grouped by error type and by specific error  
///
/// These metrics enable debugging, performance optimization, anomaly detection,
/// and operational monitoring.
///
/// ---
/// ## 🔧 Typical Usage
///
/// ```dart
/// final performance = tracker.track(() {
///   // some expensive operation
/// });
///
/// print(performance.getRunPeriod());
/// print(performance.getMemoryAnalytics().getMaximumMemoryInMegaByte());
/// print(performance.getErrorCounts());
/// ```
///
/// ---
/// ## 🔍 Design Notes
///
/// - [getRunPeriod] should always reflect real-time duration if the
///   operation is still running.
/// - Error maps must be stable and deterministic across serializations.
/// - Memory analytics should reflect the readings captured *during this
///   specific execution period*.
/// - Implementations must mix in [EqualsAndHashCode] for reliable
///   structural comparison and testing.
///
/// {@endtemplate}
abstract interface class Performance with EqualsAndHashCode implements ToJsonFactory {
/// Returns the **name** of the method, function, or class being tracked.
  ///
  /// This is typically derived from reflection, tracing metadata, or the
  /// developer-supplied label.
  String getName();

  /// Returns the **timestamp when execution started**.
  ///
  /// Used in logs, dashboards, and time-based aggregations.
  DateTime getStartTime();

  /// Returns the **timestamp when execution ended**, or the most recent
  /// recorded checkpoint if the operation is still running.
  DateTime getEndTime();

  /// Returns the **total duration** of the tracked execution.
  ///
  /// If the task is still running, this value should be computed as:
  /// `DateTime.now().difference(getStartTime())`.
  Duration getRunPeriod();

  /// Returns the **client or request IP address**, if available.
  ///
  /// Useful for per-client diagnostics, rate-limit correlation, or tracing.
  String? getIpAddress();

  /// Returns whether the tracked execution is **still running**.
  ///
  /// This should be `true` if `getEndTime()` has not yet been finalized.
  bool isRunning();

  /// Returns the [MemoryAnalytics] captured during the execution period.
  ///
  /// This enables performance tools to correlate memory spikes, leaks, or
  /// instability with specific method or class executions.
  MemoryAnalytics? getMemoryAnalytics();

  /// Returns a map of **error type → count** representing how many errors
  /// of each *category* occurred during execution.
  ///
  /// Example:
  /// ```json
  /// {
  ///   "StateError": 3,
  ///   "TimeoutException": 1
  /// }
  /// ```
  Map<String, int> getErrorTypeCounts();

  /// Returns a map of **specific error message/instance → count**.
  ///
  /// This allows more granular diagnostics than [getErrorTypeCounts].
  ///
  /// Example:
  /// ```json
  /// {
  ///   "User not found": 2,
  ///   "Invalid token": 1
  /// }
  /// ```
  Map<String, int> getErrorCounts();

  /// Gets the location of the performing object.
  /// 
  /// The location can be the method or class or instance which is being monitored.
  String getLocation();
}

/// {@template abstract_performance}
/// Base implementation of [Performance] providing common functionality
/// and utility methods for concrete performance tracking objects.
///
/// `AbstractPerformance` handles JSON serialization and provides a convenient
/// way to obtain a **read-only snapshot** of the performance data via [freeze].
///
/// Implementations of this class are expected to provide concrete logic
/// for the abstract getters defined in [Performance], such as:
/// - `getName()`
/// - `getStartTime()`
/// - `getEndTime()`
/// - `getRunPeriod()`
/// - `getIpAddress()`
/// - `isRunning()`
/// - `getMemoryAnalytics()`
/// - `getErrorTypeCounts()`
/// - `getErrorCounts()`
///
/// ---
/// ## Usage Example
/// ```dart
/// final performance = ConcretePerformance(...);
/// final frozen = performance.freeze();
/// print(frozen.getName());
/// print(frozen.getMemoryAnalytics().getAverageMemoryInMegaByte());
/// ```
/// {@endtemplate}
abstract class AbstractPerformance implements Performance {
  /// Returns a **read-only frozen snapshot** of this performance instance.
  ///
  /// The returned [_FrozenPerformance] delegates all method calls to this
  /// instance, but prevents any modification of the underlying data.
  ///
  /// Use this method when you want to safely expose performance metrics
  /// without risk of mutation.
  ///
  /// ### Example
  /// ```dart
  /// final frozenPerformance = performance.freeze();
  /// print(frozenPerformance.isRunning());
  /// ```
  Performance freeze() => _FrozenPerformance(this);

  @override
  Map<String, Object> toJson() {
    final result = {
      'name': getName(),
      'start_time': getStartTime(),
      'end_time': getEndTime(),
      'run_period_in_milliseconds': getRunPeriod().inMilliseconds,
      'is_running': isRunning(),
    };

    if (getMemoryAnalytics() case final mem?) {
      result['memory_analytics'] = mem.toJson();
    }

    if (getIpAddress() case final ip?) {
      result['ip_address'] = ip;
    }

    var counts = getErrorTypeCounts();
    if (counts.isNotEmpty) {
      result['error_type_counts'] = counts;
    }

    counts = getErrorCounts();
    if (counts.isNotEmpty) {
      result['error_counts'] = counts;
    }

    return result;
  }
}

/// {@template frozen_performance}
/// A wrapper implementation of [Performance] that provides a **read-only**
/// or **frozen view** of an existing performance instance.
///
/// `_FrozenPerformance` delegates all method calls to an underlying
/// [Performance] instance (`_src`), effectively preventing any modification
/// of the original data while still exposing the metrics.
///
/// This is useful when you want to:
/// - Expose performance metrics to external consumers safely
/// - Cache or snapshot performance data
/// - Ensure immutability when passing performance data across components
///
/// ---
/// ## Usage Example
/// ```dart
/// final perf = somePerformanceInstance;
/// final frozenPerf = _FrozenPerformance(perf);
///
/// print(frozenPerf.getName());
/// print(frozenPerf.getMemoryAnalytics().getAverageMemoryInMegaByte());
/// ```
/// {@endtemplate}
final class _FrozenPerformance implements Performance {
  /// The underlying performance instance that this frozen wrapper delegates to.
  ///
  /// All method calls are proxied to this instance.
  final Performance _src;

  /// {@macro frozen_performance}
  _FrozenPerformance(this._src);

  @override
  String getName() => _src.getName();
  
  @override
  DateTime getStartTime() => _src.getStartTime();
  
  @override
  DateTime getEndTime() => _src.getEndTime();
  
  @override
  Duration getRunPeriod() => _src.getRunPeriod();
  
  @override
  String? getIpAddress() => _src.getIpAddress();
  
  @override
  bool isRunning() => _src.isRunning();
  
  @override
  MemoryAnalytics? getMemoryAnalytics() => _src.getMemoryAnalytics();
  
  @override
  Map<String, int> getErrorTypeCounts() => _src.getErrorTypeCounts();
  
  @override
  Map<String, int> getErrorCounts() => _src.getErrorCounts();

  @override
  String getLocation() => _src.getLocation();

  @override
  Map<String, Object> toJson() => _src.toJson();

  @override
  List<Object?> equalizedProperties() => _src.equalizedProperties();
}