import 'memory_analytics.dart';
import 'performance.dart';

/// {@template configurable_performance}
/// A **mutable implementation** of [Performance], intended for constructing,
/// editing, testing, or manually instrumenting performance data.
///
/// Unlike read-only snapshots, instances of `ConfigurablePerformance` allow
/// modification of all internal state, including name, timestamps, status,
/// memory analytics, and error counters.
///
/// Typically, after populating a `ConfigurablePerformance` object, you may
/// call [freeze] (inherited from [AbstractPerformance]) to obtain an
/// immutable [_FrozenPerformance] snapshot suitable for public exposure.
///
/// ---
/// ## Mutable Fields
/// - `_name` — The name of the operation or class being tracked.
/// - `_startTime` — When the operation started.
/// - `_endTime` — When the operation ended (or will end if still running).
/// - `_isRunning` — Boolean flag indicating if the operation is ongoing.
/// - `_ipAddress` — Optional client or host IP address associated with the operation.
/// - `_memoryAnalytics` — Tracks memory usage during the operation.
/// - `_errorTypeCounts` — Counts of errors categorized by type (e.g., exceptions).
/// - `_errorCounts` — Counts of individual error messages.
///
/// ---
/// ## Example Usage
/// ```dart
/// final perf = ConfigurablePerformance(name: 'UserService.save');
/// perf.setStartTime(DateTime.now());
/// // ... perform operation ...
/// perf.addErrorCount('TimeoutException', 1);
/// perf.setEndTime(DateTime.now());
/// final frozen = perf.freeze(); // Immutable snapshot
/// ```
/// {@endtemplate}
class ConfigurablePerformance extends AbstractPerformance {
  /// Name of the operation or class being tracked.
  final String _name;

  /// Timestamp marking the start of the operation.
  DateTime _startTime;

  /// Timestamp marking the end of the operation.
  DateTime _endTime;

  /// Duration taken by the operation.
  Duration? _upTime;

  /// Whether the operation is currently running.
  bool _isRunning;

  /// Optional IP address associated with the operation.
  String? _ipAddress;

  /// The origin of the object
  String _location;

  /// Tracks memory metrics during execution.
  MemoryAnalytics? _memoryAnalytics;

  /// Counts of errors grouped by error type.
  final Map<String, int> _errorTypeCounts = {};

  /// Counts of errors by specific message.
  final Map<String, int> _errorCounts = {};

  /// {@macro configurable_performance}
  ConfigurablePerformance({
    required String name,
    DateTime? startTime,
    DateTime? endTime,
    bool isRunning = true,
    String? ipAddress,
    required String location,
    MemoryAnalytics? memoryAnalytics,
  }) : _name = name,
      _startTime = startTime ?? DateTime.now(),
      _endTime = endTime ?? (endTime ?? DateTime.now()),
      _isRunning = isRunning,
      _ipAddress = ipAddress,
      _location = location,
      _memoryAnalytics = memoryAnalytics;

  @override
  String getName() => _name;

  @override
  DateTime getStartTime() => _startTime;

  @override
  String getLocation() => _location;

  @override
  DateTime getEndTime() => _isRunning ? DateTime.now() : _endTime;

  @override
  Duration getRunPeriod() => _upTime ?? getEndTime().difference(_startTime);

  @override
  String? getIpAddress() => _ipAddress;

  @override
  bool isRunning() => _isRunning;

  @override
  MemoryAnalytics? getMemoryAnalytics() => _memoryAnalytics;

  @override
  Map<String, int> getErrorTypeCounts() => Map.unmodifiable(_errorTypeCounts);

  @override
  Map<String, int> getErrorCounts() => Map.unmodifiable(_errorCounts);

  // ------------------------------------------------------------
  // Mutator methods
  // ------------------------------------------------------------

  /// Updates the start time of the operation.
  ///
  /// **Parameters:**
  /// - [time]: The new start timestamp.
  ///
  /// **Usage Example:**
  /// ```dart
  /// perf.setStartTime(DateTime.now());
  /// ```
  void setStartTime(DateTime time) => _startTime = time;

  /// Updates the duration of the operation.
  ///
  /// **Parameters:**
  /// - [time]: The new duration timestamp.
  ///
  /// **Usage Example:**
  /// ```dart
  /// perf.setUptime(Duration());
  /// ```
  void setUptime(Duration duration) => _upTime = duration;

  /// Updates the end time of the operation and marks it as not running.
  ///
  /// **Parameters:**
  /// - [time]: The new end timestamp.
  ///
  /// **Behavior:**
  /// - Sets `_endTime` to the given time.
  /// - Updates `_isRunning` to `false`.
  ///
  /// **Usage Example:**
  /// ```dart
  /// perf.setEndTime(DateTime.now());
  /// ```
  void setEndTime(DateTime time) {
    _endTime = time;
    _isRunning = false;
  }

  /// Updates whether the operation is currently running.
  ///
  /// **Parameters:**
  /// - [running]: `true` if the operation is running; `false` otherwise.
  ///
  /// **Behavior:**
  /// - If set to `false`, `_endTime` is updated to `DateTime.now()`.
  ///
  /// **Usage Example:**
  /// ```dart
  /// perf.setIsRunning(false);
  /// ```
  void setIsRunning(bool running) {
    _isRunning = running;
    if (!running) _endTime = DateTime.now();
  }

  /// Sets or updates the IP address associated with the operation.
  ///
  /// **Parameters:**
  /// - [ip]: Optional IP address.
  ///
  /// **Usage Example:**
  /// ```dart
  /// perf.setIpAddress('192.168.0.1');
  /// ```
  void setIpAddress(String? ip) => _ipAddress = ip;

  /// Replaces the internal memory analytics with the provided instance.
  ///
  /// **Parameters:**
  /// - [analytics]: A new [MemoryAnalytics] instance to track memory.
  ///
  /// **Usage Example:**
  /// ```dart
  /// perf.setMemoryAnalytics(myAnalytics);
  /// ```
  void setMemoryAnalytics(MemoryAnalytics analytics) {
    _memoryAnalytics = analytics;
  }

  /// Adds or increments a count for a specific error type.
  ///
  /// **Parameters:**
  /// - [type]: The error type (e.g., 'TimeoutException').
  ///
  /// **Behavior:**
  /// - If the type already exists, increments its count by 1.
  /// - Otherwise, initializes it to 1.
  ///
  /// **Usage Example:**
  /// ```dart
  /// perf.addErrorTypeCount('TimeoutException', 1);
  /// ```
  void addErrorTypeCount(String type) {
    _errorTypeCounts[type] = (_errorTypeCounts[type] ?? 0) + 1;
  }

  /// Adds or increments a count for a specific error message.
  ///
  /// **Parameters:**
  /// - [message]: The error message string.
  ///
  /// **Behavior:**
  /// - If the message already exists, increments its count by 1.
  /// - Otherwise, initializes it to 1.
  ///
  /// **Usage Example:**
  /// ```dart
  /// perf.addErrorCount('Failed to save user');
  /// ```
  void addErrorCount(String message) {
    _errorCounts[message] = (_errorCounts[message] ?? 0) + 1;
  }

  @override
  List<Object?> equalizedProperties() => [
    _name,
    _startTime,
    _endTime,
    _isRunning,
    _ipAddress,
    _memoryAnalytics,
    _errorTypeCounts,
    _errorCounts,
  ];
}