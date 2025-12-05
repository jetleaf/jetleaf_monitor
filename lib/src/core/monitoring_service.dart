import '../base/memory_analytics.dart';
import '../base/memory_reading.dart';
import '../base/monitoring_report.dart';
import '../base/performance.dart';

/// {@template monitoring_service}
/// Provides runtime observability for memory usage, performance tracking,
/// and historical diagnostic data within a JetLeaf application.
///
/// A `MonitoringService` implementation acts as the central orchestrator
/// for all monitoring-related information, exposing:
///
/// - A continuous **stream of memory readings**
/// - Computed **memory analytics** over configurable windows
/// - **Historical memory readings** for diagnostics and trend analysis
/// - **Performance snapshots** for specific tracked methods/classes
///
/// This service is typically consumed by:
/// - Diagnostic endpoints (REST/CLI)
/// - Observability dashboards
/// - Performance profilers
/// - Telemetry exporters
/// - Automated resource management tools
///
/// Implementations are expected to be thread-safe and performant, as this
/// service may be accessed frequently throughout the application lifecycle.
///
/// {@endtemplate}
abstract interface class MonitoringService {
  /// Returns a **stream of live [MemoryReading] events**, emitted as the system
  /// captures memory snapshots over time.
  ///
  /// ### Behavior
  /// - Readings are typically emitted at fixed intervals.
  /// - Consumers may subscribe for dashboards, alerts, or continuous analytics.
  /// - The stream must never close unless the service is intentionally
  ///   shut down.
  ///
  /// ### Example
  /// ```dart
  /// monitoringService.getMemoryReadingStream().listen((reading) {
  ///   print('Current memory: ${reading.getMemoryInMegaByte()} MB');
  /// });
  /// ```
  Stream<MemoryReading> getMemoryReadingStream();

  /// Returns computed [MemoryAnalytics] for the given optional [duration]
  /// window.
  ///
  /// ### Parameters
  /// - `duration` *(optional)* — Limits analytics to readings captured within
  ///   the specified time window.  
  ///   If omitted, implementations should use their default observation window
  ///   (e.g., last 60 seconds or entire history).
  ///
  /// ### Example
  /// ```dart
  /// final analytics = monitoring.getMemoryAnalytics(Duration(minutes: 5));
  /// print(analytics.getAverageMemoryInMegaByte());
  /// ```
  ///
  /// ### Notes
  /// - Implementations must handle the case where insufficient readings exist.
  /// - Returned analytics should be consistent and deterministic.
  AbstractMemoryAnalytics getMemoryAnalytics([Duration? duration]);

  /// Returns the **full list of collected [MemoryReading] snapshots**.
  ///
  /// This is typically used for:
  /// - Debugging memory leaks  
  /// - Plotting charts in dashboards  
  /// - Exporting raw telemetry  
  /// - Retrospective diagnostics  
  ///
  /// Implementations may choose whether to:
  /// - Return all readings ever captured  
  /// - Limit the retained history by size or time window  
  ///
  /// The returned list should be in chronological order.
  List<MemoryReading> getMemoryHistory();

  /// Returns a tracked [Performance] record for the given executable [name],
  /// or `null` if no performance data exists for that identifier.
  ///
  /// ### Typical Usage
  /// ```dart
  /// final perf = monitoring.getPerformance('Database.query');
  /// if (perf != null) {
  ///   print(perf.getRunPeriod());
  /// }
  /// ```
  ///
  /// ### Notes
  /// - Names must match whatever identifier was used when the performance
  ///   event was recorded.
  /// - Returned instances should be immutable snapshots.
  Performance? getPerformance(String name);

  /// Returns a **list of all recorded [Performance] snapshots** currently
  /// maintained by the monitoring subsystem.
  ///
  /// Each `Performance` entry represents aggregated execution metrics for a
  /// specific monitored method or class, typically created via:
  /// - `@Monitor()` annotations  
  /// - Explicit performance tracking calls within the application  
  ///
  /// ### Example
  /// ```dart
  /// final performances = monitoring.getPerformances();
  /// for (final perf in performances) {
  ///   print('${perf.getName()}: ${perf.getRunPeriod()}');
  /// }
  /// ```
  ///
  /// ### Use Cases
  /// - Dashboard rendering of all performance metrics  
  /// - Bulk export for telemetry or diagnostics  
  /// - Detecting hotspots or slow-running application components  
  ///
  /// Implementations should ensure thread-safe access to internal
  /// performance-tracking structures.
  List<Performance> getPerformances();

  /// Generates and returns a **comprehensive monitoring snapshot** encapsulated
  /// in a [MonitoringReport].
  ///
  /// A report represents the **current state of the monitoring subsystem** at
  /// the moment of invocation, aggregating:
  ///
  /// - **Process information** (PID, platform, runtime, host details)
  /// - **Application start time** (if available via [StartupTracker])
  /// - **Total uptime** computed from the earliest tracked start event
  /// - **Complete memory history** (all retained [MemoryReading] entries)
  /// - **Computed memory analytics** over the service’s configured window
  ///
  /// ### Example
  /// ```dart
  /// final MonitoringReport report = monitoringService.getReport();
  /// print(report.toJson());
  /// ```
  MonitoringReport getReport();
}