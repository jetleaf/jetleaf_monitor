import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_logging/logging.dart';
import 'package:jetleaf_monitor/src/base/monitoring_report.dart';
import 'package:jetleaf_pod/pod.dart';
import 'package:meta/meta.dart';

import '../annotations.dart';
import '../base/default_memory_analytics.dart';
import '../base/default_memory_reading.dart';
import '../base/default_monitoring_report.dart';
import '../base/default_process_information.dart';
import '../base/memory_analytics.dart';
import '../base/memory_reading.dart';
import 'instance_performance_tracker.dart';
import 'monitoring_service.dart';

/// Provides a full-featured, periodic memory-monitoring service with support for:
/// * real-time memory sampling,
/// * rolling historical memory retention,
/// * min/max/avg analytics computation over dynamic windows,
/// * baseline (initial-window) memory evaluation,
/// * GC delta tracking,
/// * structured diagnostic reporting,
/// * and integration with performance-tracking annotations.
///
/// The service operates on a fixed sampling interval, defined by [getInterval],
/// during which it collects:
/// * current Resident Set Size (RSS) memory,
/// * application uptime,
/// * timestamped memory readings that persist for up to 24 hours.
///
/// All memory readings are emitted through a broadcast stream, enabling
/// external observers (dashboards, log sinks, diagnostics) to subscribe to
/// real-time updates without interfering with sampling.
///
/// Memory analytics (via [getMemoryAnalytics]) are computed on demand and
/// include:
/// * minimum memory observed within the window,
/// * maximum memory observed,
/// * average memory consumption,
/// * current memory snapshot,
/// * and the underlying reading set.
///
/// The monitoring service also performs higher-order analysis, such as:
/// * last-hour min/max/avg computations,
/// * early-lifecycle “initial window” trend detection,
/// * GC-related memory reclamation accumulation.
///
/// Subclasses must configure the sampling cadence, analytics window,
/// startup-tracking provider, and logging adapter by implementing the abstract
/// configuration methods at the bottom of this class.
///
/// This service is designed to be production-safe: low-overhead, allocation-thin,
/// and non-blocking.
abstract class AbstractMonitoringService extends InstancePerformanceTracker implements MonitoringService, Lifecycle {
  /// Indicates whether the monitoring service is currently running.
  bool _isRunning = false;

  /// Periodic timer responsible for sampling memory usage.
  Timer? _memoryTimer;

  /// Last captured resident set size in bytes.
  ///
  /// Used to identify GC-related memory reclamation deltas.
  int _lastRss = 0;

  /// Accumulated total memory freed by GC over the application's lifetime.
  int _gcMemoryFreed = 0;

  /// Historical list of memory readings collected during the monitoring cycle.
  ///
  /// This includes timestamp, memory usage, and uptime information.
  final List<MemoryReading> _memoryReadings = [];

  /// Broadcast stream controller that emits new memory readings as they occur.
  ///
  /// Subscribers can observe real-time memory activity.
  final StreamController<MemoryReading> _memoryController = StreamController<MemoryReading>.broadcast();

  /// Creates a unified, stable key for performance tracking entries.
  ///
  /// The resolution process:
  /// 1. If an explicit Pod name is provided → use it.
  /// 2. Otherwise, if the `@Monitor(name: ...)` annotation provides a name → use it.
  /// 3. If monitoring a method → use `<QualifiedClass>#<methodName>`.
  /// 4. If monitoring a class → use the class's fully-qualified name.
  /// 5. Fallback → use the source’s signature string.
  ///
  /// This ensures consistent, predictable identity for monitoring sources.
  @protected
  String createKey(Monitor monitor, Source source, String? name) {
    // 1. Explicit name always wins
    if (name != null) {
      return name;
    }

    // 2. Annotation name wins next
    if (monitor.name case final name?) {
      return name;
    }

    // 3. Methods → <package>::<Class>.<method>
    if (source case Method method) {
      final cls = method.getDeclaringClass();
      final pkg = cls.getPackage().getName();
      final className = cls.getSimpleName();
      final methodName = method.getName();
      return "$pkg::$className.$methodName";
    }

    // 4. Classes → <package>::<Class>
    if (source case Class cls) {
      final pkg = cls.getPackage().getName();
      final className = cls.getSimpleName();
      return "$pkg::$className";
    }

    // 5. Fallback
    return source.getSignature();
  }

  /// Resolves a **human-readable, fully-qualified location string** for the
  /// given [Source], representing where a monitored element originates.
  ///
  /// Unlike [createKey], which focuses on producing a **stable identifier** for
  /// performance-tracking purposes, `getLocation` is intended for:
  /// - Diagnostic output  
  /// - Logging  
  /// - Report generation  
  /// - Human-facing summaries
  ///
  /// ### Purpose
  /// - Ensures consistent and meaningful display of where performance or
  ///   monitoring events originate.
  /// - Enables users to quickly identify problematic methods/classes in logs
  ///   and diagnostic reports.
  ///
  /// ### Example
  /// ```dart
  /// final location = getLocation(methodSource);
  /// print('Performance hotspot at: $location');
  /// ```
  ///
  /// Returns a string suitable for logs, reports, and human inspection.
  @protected
  String getLocation(Source source) {
    if (source case Method method) {
      final declaring = method.getDeclaringClass();
      return "${declaring.getQualifiedName()}#${method.getName()}";
    }

    if (source case Class cls) {
      return cls.getQualifiedName();
    }

    return source.getSignature();
  }

  @override
  AbstractMemoryAnalytics getMemoryAnalytics([Duration? duration]) {
    final now = DateTime.now();
    duration = duration ?? getAnalyticsInterval();
    final cutoff = now.subtract(duration);
    final relevantReadings = _memoryReadings.where((reading) => reading.getCreatedAt().isAfter(cutoff)).toList();
    
    if (relevantReadings.isEmpty) {
      return DefaultMemoryAnalytics(
        timeWindow: duration,
        minMemoryMB: _getCurrentMemoryUsage(),
        maxMemoryMB: _getCurrentMemoryUsage(),
        avgMemoryMB: _getCurrentMemoryUsage(),
        currentMemoryMB: _getCurrentMemoryUsage(),
        readings: [],
      );
    }
    
    final memoryValues = relevantReadings.map((r) => r.getMemoryInMegaByte().value).toList();
    final minMemory = memoryValues.reduce((a, b) => a < b ? a : b);
    final maxMemory = memoryValues.reduce((a, b) => a > b ? a : b);
    final avgMemory = memoryValues.reduce((a, b) => a + b) / memoryValues.length;
    
    return DefaultMemoryAnalytics(
      timeWindow: duration,
      minMemoryMB: minMemory,
      maxMemoryMB: maxMemory,
      avgMemoryMB: avgMemory,
      currentMemoryMB: _getCurrentMemoryUsage(),
      readings: List.unmodifiable(relevantReadings),
    );
  }

  @override
  List<MemoryReading> getMemoryHistory() => UnmodifiableListView(_memoryReadings);

  @override
  Stream<MemoryReading> getMemoryReadingStream() => _memoryController.stream;

  @override
  FutureOr<void> start() async {
    if (_isRunning) {
      return;
    }

    _memoryTimer = Timer.periodic(getInterval(), (timer) {
      final now = DateTime.now();
      final memoryUsageMB = _getCurrentMemoryUsage();
      final currentUptime = _getUptime();
      
      // Create and store memory reading
      final reading = DefaultMemoryReading(timestamp: now, memoryMB: memoryUsageMB, uptime: currentUptime);
      
      _memoryReadings.add(reading);
      _memoryController.add(reading);
      
      // Log current memory usage
      final timeStamp = _formatDateTime(now);
      if (getLogger() case final logger) {
        if (logger.getIsTraceEnabled()) {
          logger.trace("Current Memory Usage: ${memoryUsageMB.toStringAsFixed(2)}MB [$timeStamp]");
        }
      }
      
      // Analyze and log memory patterns
      _analyzeAndLogMemoryPatterns(memoryUsageMB, now);
      
      // Clean up old readings (keep last 24 hours)
      _cleanupOldReadings();
    });
  }

  /// Returns the current Resident Set Size (RSS) memory usage of the running
  /// process, expressed in megabytes (MB).
  ///
  /// The value is sourced from:
  /// ```
  /// ProcessInfo.currentRss   // RSS in bytes
  /// ```
  /// and converted to megabytes via:
  /// ```
  /// memoryMB = currentRss / (1024 * 1024)
  /// ```
  ///
  /// ### Notes
  /// * The returned value reflects the OS-reported RSS, not Dart heap usage.
  /// * This method does not round the value; callers may format it for display.
  /// * RSS may decrease after garbage-collection cycles or OS compaction events.
  ///
  /// ### Used By
  /// * periodic sampling loop in [start],
  /// * memory-analytics aggregation,
  /// * monitoring reports,
  /// * initial-window (warm-up) analysis.
  double _getCurrentMemoryUsage() => ProcessInfo.currentRss / (1024 * 1024);

  /// Computes total uptime of the monitored application based on the
  /// startup timestamp provided by the active [StartupTracker], if any.
  ///
  /// If the startup time is known:
  /// ```
  /// return DateTime.now().difference(appStartTime)
  /// ```
  ///
  /// Otherwise, returns `Duration.zero`, meaning uptime cannot be determined.
  ///
  /// Uptime is stored in memory readings and included in monitoring reports.
  Duration _getUptime() {
    if (_getAppStartTime() case final start?) {
      return DateTime.now().difference(start);
    }

    return Duration.zero;
  }

  /// Formats a [DateTime] into a fixed canonical logging format:
  ///
  /// ```
  /// YYYY-MM-DD HH:mm
  /// ```
  ///
  /// Example:
  /// `2025-03-19 14:07`
  ///
  /// Used in memory sampling logs for consistent timestamp presentation across
  /// environments.
  String _formatDateTime(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-"
           "${dt.month.toString().padLeft(2, '0')}-"
           "${dt.day.toString().padLeft(2, '0')} "
           "${dt.hour.toString().padLeft(2, '0')}:"
           "${dt.minute.toString().padLeft(2, '0')}";
  }

  /// Analyzes recent memory usage and logs memory patterns at various
  /// timescales:
  ///
  /// **1. Last-hour analytics**
  /// * Computes min/max/avg over the last hour.
  /// * Logs these values if logging is enabled.
  ///
  /// **2. Initial window analysis**
  /// Evaluates memory deltas relative to an "initial stability window"
  /// beginning shortly after startup (e.g., 3–13 minutes).
  ///
  /// This is typically used to detect:
  /// * early leaks
  /// * excessive warm-up allocation
  /// * baseline memory stabilization characteristics
  ///
  /// Log messages include:
  /// * min/max memory in the window
  /// * deltas from current value
  /// * uptime display
  ///
  /// If no readings exist in the initial window, a minimal trace line is logged.
  void _analyzeAndLogMemoryPatterns(double currentMemory, DateTime now) {
    // Last hour analysis
    final lastHourAnalytics = getMemoryAnalytics(const Duration(hours: 1));
    if (lastHourAnalytics.getReadings().isNotEmpty) {
      if (getLogger() case final logger) {
        if (logger.getIsTraceEnabled()) {
          logger.trace(
            "Last hour - Min: ${lastHourAnalytics.getMinimumMemoryInMegaByteString()}, "
            "Max: ${lastHourAnalytics.getMaximumMemoryInMegaByteString()}, "
            "Avg: ${lastHourAnalytics.getAverageMemoryInMegaByteString()}\n"
            "Deltas - Min: ${lastHourAnalytics.getMinimumDeltaString()}, "
            "Max: ${lastHourAnalytics.getMaximumDeltaString()}"
          );
        }
      }
    }
    
    // Initial window analysis (3-13 minutes after start)
    if (_getAppStartTime() case final appStartTime?) {
      final initStart = appStartTime.add(const Duration(minutes: 3));
      final initEnd = appStartTime.add(const Duration(minutes: 13));
      final initReadings = _memoryReadings.where((r) => r.getCreatedAt().isAfter(initStart) && r.getCreatedAt().isBefore(initEnd)).toList();
      
      final uptimeStr = _formatDuration(_getUptime());
      
      if (initReadings.isNotEmpty) {
        final initValues = initReadings.map((r) => r.getMemoryInMegaByte().value).toList();
        final minInit = initValues.reduce((a, b) => a < b ? a : b);
        final maxInit = initValues.reduce((a, b) => a > b ? a : b);

        if (getLogger() case final logger) {
          if (logger.getIsTraceEnabled()) {
            logger.trace(
              "Init window (${getInitWindowAnalysisStart().inHours}-${getInitWindowAnalysisEnd().inMinutes}min), uptime: $uptimeStr\n"
              "Min: ${minInit.toStringAsFixed(2)}MB, Max: ${maxInit.toStringAsFixed(2)}MB\n"
              "Deltas - Min: ${(currentMemory - minInit).toStringAsFixed(2)}MB, "
              "Max: ${(currentMemory - maxInit).toStringAsFixed(2)}MB"
            );
          }
        }
      } else {
        if (getLogger() case final logger) {
          if (logger.getIsTraceEnabled()) {
            logger.trace("Init window (${getInitWindowAnalysisStart().inHours}-${getInitWindowAnalysisEnd().inMinutes}min), uptime: $uptimeStr\n");
          }
        }
      }
    }
  }

  /// Retrieves the application's startup timestamp, if available.
  ///
  /// If a [StartupTracker] is present (provided by [getStartupTracker]),
  /// the timestamp is extracted from:
  /// ```
  /// tracker.getStartTime() // milliseconds since epoch
  /// ```
  ///
  /// Returns `null` if:
  /// * no startup tracker has been configured, or
  /// * startup time is not known.
  DateTime? _getAppStartTime() {
    if (getStartupTracker() case final tracker?) {
      return DateTime.fromMillisecondsSinceEpoch(tracker.getStartTime());
    }

    return null;
  }
  
  /// Formats a [Duration] into a compact, human-readable representation.
  ///
  /// Formatting rules:
  /// * If duration contains hours → `"Xh"` or `"XhYm"`
  /// * If no hours but contains minutes → `"Xm"` or `"XmYs"`
  /// * Otherwise → `"Xs"`
  ///
  /// Examples:
  /// ```
  /// 1h 0m         → "1h"
  /// 1h 25m        → "1h25m"
  /// 12m 10s       → "12m10s"
  /// 45s           → "45s"
  /// ```
  ///
  /// Used for logging uptime in memory-analysis output.
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0 && minutes > 0) {
      return "${hours}h${minutes}m";
    } else if (hours > 0) {
      return "${hours}h";
    } else if (minutes > 0 && seconds > 0) {
      return "${minutes}m${seconds}s";
    } else if (minutes > 0) {
      return "${minutes}m";
    } else {
      return "${seconds}s";
    }
  }

  /// Removes memory readings older than 24 hours.
  ///
  /// This ensures that the internal memory history list never grows indefinitely,
  /// while still preserving enough historical data for analytics and reporting.
  ///
  /// The cutoff is computed as:
  /// ```
  /// DateTime.now() - Duration(hours: 24)
  /// ```
  /// Any reading whose timestamp falls before the cutoff is discarded.
  void _cleanupOldReadings() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    _memoryReadings.removeWhere((reading) => reading.getCreatedAt().isBefore(cutoff));
  }

  @override
  FutureOr<void> stop([Runnable? callback]) async {
    _memoryTimer?.cancel();
    _memoryTimer = null;
    await _memoryController.close();
    _isRunning = false;
  }

  @override
  bool isRunning() => _isRunning;

  @override
  MonitoringReport getReport() {
    final currentRss = ProcessInfo.currentRss;

    if (_lastRss > 0 && currentRss < _lastRss) {
      _gcMemoryFreed += (_lastRss - currentRss);
    }
    _lastRss = currentRss;

    return DefaultMonitoringReport(
      DefaultProcessInformation(currentRss, _gcMemoryFreed, ProcessInfo.maxRss),
      _getAppStartTime() ?? DateTime.now(),
      getMemoryAnalytics(),
      _memoryReadings,
      _getUptime()
    );
  }

  // =======================================================================
  // Abstract Configuration Methods
  // =======================================================================

  /// Returns the interval at which memory usage should be captured.
  ///
  /// Typical values might be:
  /// * `Duration(seconds: 5)`
  /// * `Duration(seconds: 30)`
  /// * `Duration(minutes: 1)`
  ///
  /// Subclasses must override this to configure sampling frequency.
  @protected
  Duration getInterval();

  /// Returns the time window over which aggregated memory analytics
  /// (min/max/avg) should be computed.
  ///
  /// Common values include:
  /// * Last 1 minute
  /// * Last 5 minutes
  /// * Last 1 hour
  ///
  /// This affects `getMemoryAnalytics()`.
  @protected
  Duration getAnalyticsInterval();

  /// Returns a startup tracker instance, if available.
  ///
  /// Provides application startup metadata such as:
  /// * Exact start timestamp
  /// * Boot operation timings
  ///
  /// If `null`, startup-time analytics are disabled.
  @protected
  StartupTracker? getStartupTracker();

  /// Returns the duration representing the *start* of the “initial window”
  /// memory analysis phase.
  ///
  /// This is typically a few minutes after the application starts, allowing
  /// the system to stabilize before evaluating memory baselines.
  ///
  /// Example:
  /// ```dart
  /// Duration(minutes: 3)
  /// ```
  @protected
  Duration getInitWindowAnalysisStart();

  /// Returns the duration representing the *end* of the “initial window”
  /// memory analysis phase.
  ///
  /// Example:
  /// ```dart
  /// Duration(minutes: 13)
  /// ```
  ///
  /// The initial window (start → end) is used to compute early memory deltas.
  @protected
  Duration getInitWindowAnalysisEnd();

  /// Returns the logger used for emitting monitoring diagnostics.
  ///
  /// Implementations typically return a service-specific logger:
  ///
  /// ```dart
  /// @override
  /// Log getLogger() => Logs.getLogger("MonitoringService");
  /// ```
  ///
  /// If the logger is `null`, no log output is emitted.
  @protected
  Log getLogger();
}