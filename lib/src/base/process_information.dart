import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_lang/lang.dart';

/// {@template process_information}
/// Provides an abstraction for retrieving detailed runtime and operating-system–
/// level information about the current Dart process.
///
/// `ProcessInformation` acts as a unified interface for any component that needs
/// insights into memory usage, system capabilities, environment metadata, or
/// host-level configuration. Implementations may pull values directly from the
/// platform (e.g. `Platform`, `ProcessInfo`, OS APIs) or any custom telemetry
/// backend.
///
/// This interface is commonly used by:
/// - Performance and memory diagnostics
/// - System-health dashboards
/// - Telemetry exporters
/// - Environment-aware optimizers
/// - Crash-reporters and runtime analytics
///
/// Implementations must be **side-effect free**, must not perform heavy
/// computations in property getters, and should return values in consistent
/// units (JetLeaf’s [`Integer`] abstraction).
///
/// All values returned by this interface **must be serializable**, as the type
/// implements [ToJsonFactory].
///
/// ### Example
/// ```dart
/// final info = DefaultProcessInformation();
///
/// print('RSS: ${info.getCurrentResidentSetSizeMemory()} MB');
/// print('OS: ${info.getOperatingSystem()} ${info.getOperatingSystemVersion()}');
/// print('CPUs: ${info.getNumberOfProcessors()}');
/// print('Locale: ${info.getLocaleName()}');
/// ```
///
/// ### Notes
/// - Memory values should represent the process’s resident set size (RSS) in MB  
/// - Strings must never be null; implementations should fallback gracefully  
/// - CPU count must reflect logical processors  
/// - `FreedMemory` represents memory reclaimed since process start (if supported)  
/// - `LocaleName` should follow standard OS locale formatting  
///
/// {@endtemplate}
abstract interface class ProcessInformation with EqualsAndHashCode implements ToJsonFactory {
  /// Returns the current **resident set size (RSS)** of the process in megabytes.
  ///
  /// RSS represents how much physical memory the process is actively using.
  /// Implementations should report this as an [`Integer`] value in MB.
  Integer getCurrentResidentSetSizeMemory();

  /// Returns the maximum resident set size observed since process start,  
  /// reported in megabytes.
  ///
  /// This is commonly referred to as the **peak RSS**, indicating the highest
  /// memory footprint the process has reached.
  Integer getMaxResidentSetSizeMemory();

  /// Returns the amount of memory that has been **freed or reclaimed** by the
  /// process, reported in megabytes.
  ///
  /// Not all platforms expose this directly; where unsupported, implementations
  /// should return `Integer.zero`.
  Integer getFreedMemory();

  /// Returns the name of the **operating system**, such as `"linux"`, `"macos"`,
  /// or `"windows"`.
  String getOperatingSystem();

  /// Returns the OS version string as reported by the underlying platform.
  ///
  /// For example:
  /// - `"Ubuntu 22.04"`
  /// - `"macOS 14.5"`
  /// - `"Windows 11 (Build 22621)"`
  String getOperatingSystemVersion();

  /// Returns the number of **logical CPU processors** available to the process.
  ///
  /// This typically corresponds to the hardware thread count reported by the OS.
  Integer getNumberOfProcessors();

  /// Returns the version of Dart currently running this process.
  ///
  /// Typically matches `Platform.version` but may be normalized by the implementation.
  String getDartVersion();

  /// Returns the local machine’s host name.
  ///
  /// Should reflect the system’s configured host identifier (e.g. `"dev-machine"`,
  /// `"prod-server-12"`).
  String getLocalHostName();

  /// Returns the locale name currently in use by the process.
  ///
  /// Format typically follows:
  /// - `"en_US"`
  /// - `"fr_FR"`
  /// - `"zh_CN"`
  ///
  /// Should match OS locale rules where possible.
  String getLocaleName();
}