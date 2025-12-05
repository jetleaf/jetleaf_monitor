import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';

import 'memory_analytics.dart';
import 'memory_reading.dart';
import 'process_information.dart';

/// {@template monitoring_report}
/// Represents a full, structured snapshot of the application's runtime health,
/// combining process-level metadata, memory analytics, and historical readings.
///
/// A `MonitoringReport` is the primary diagnostic payload used throughout
/// JetLeaf for:
/// - Telemetry exports  
/// - Health-check endpoints  
/// - Diagnostic dashboards  
/// - Snapshot-based performance analysis  
///
/// Implementations must serialize all fields deterministically via
/// [ToJsonFactory], and must include complete information about the app’s
/// lifecycle, memory profile, and environment.
///
/// ### Contents of a Monitoring Report
///
/// A typical report includes:
/// - **Application Start Time** — when the application began execution  
/// - **Total Uptime** — how long the application has been running  
/// - **Memory History** — chronological list of raw memory readings  
/// - **Memory Analytics** — aggregated insights over the memory history  
/// - **Process Information** — OS, CPU, memory, and runtime details  
///
/// ### Usage
/// Monitoring reports are produced by system components such as:
/// - `MonitoringService`  
/// - `DiagnosticsController`  
/// - `SystemSnapshot` exporters  
///
/// They act as the foundation for understanding the application's operational
/// state at any given moment.
///
/// Implementations must be **immutable**, represent a single snapshot in time,
/// and be safe for logging, exporting, or dashboard presentation.
///
/// {@endtemplate}
abstract interface class MonitoringReport with EqualsAndHashCode implements ToJsonFactory {
/// Returns the exact **startup time** of the application.
  ///
  /// This value does not change across the lifetime of the app and is used to
  /// compute uptime and track restarts.
  DateTime getAppStartTime();

  /// Returns the **total elapsed time** since [getAppStartTime].
  ///
  /// Implementations should compute this as:
  /// `DateTime.now().difference(getAppStartTime())`
  ///
  /// Consumers use uptime to detect:
  /// - Restart cycles  
  /// - Long-running process drift  
  /// - Scheduling alignment  
  Duration getTotalUptime();

  /// Returns the chronological list of collected [MemoryReading] objects.
  ///
  /// These represent the raw memory usage snapshots from which analytics are
  /// derived. Implementations should return this list as:
  /// - **Chronological** (oldest → newest)  
  /// - **Immutable** (unmodifiable view or defensive copy)  
  List<MemoryReading> getMemoryHistory();

  /// Returns the computed [MemoryAnalytics] instance derived from
  /// [getMemoryHistory].
  ///
  /// This provides aggregated metrics such as:
  /// - Minimum memory  
  /// - Maximum memory  
  /// - Average memory  
  /// - Current (last) memory  
  /// - Time window of evaluation  
  MemoryAnalytics getMemoryAnalytics();

  /// Returns a [ProcessInformation] snapshot describing the environment in which
  /// the app is running.
  ///
  /// This includes:
  /// - OS and version  
  /// - CPU count  
  /// - Dart version  
  /// - Host and locale  
  /// - Resident set size (RSS) info  
  ///
  /// This data is essential for diagnostics and environment-aware optimizers.
  ProcessInformation getProcessInformation();
}