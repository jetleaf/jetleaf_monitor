import 'dart:io';

import 'package:jetleaf_lang/lang.dart';

import 'process_information.dart';

/// {@template default_process_information}
/// Default implementation of [ProcessInformation] that provides
/// metadata about the current running Dart process and the underlying
/// operating system.
///
/// This class surfaces runtime characteristics such as memory usage,
/// processor count, OS information, locale, and host details. It also
/// exposes custom inputs such as the tracked resident memory values
/// (`_currentRss`, `_freedMemory`, `_maxRss`) and an explicit version
/// identifier supplied during instantiation.
///
/// JetLeaf components use this implementation when collecting
/// environment diagnostics, telemetry, or performance insights.
///
/// ## Memory Values
/// - `_currentRss`: Current Resident Set Size (RSS) of the process
/// - `_freedMemory`: Amount of memory freed since last measurement
/// - `_maxRss`: Maximum RSS observed during the process lifetime
///
/// ## Version Field
/// - `_version`: A JetLeaf-defined or user-defined version string
///
/// ## Notes
/// Platform-derived values (locale, host name, processors, OS, etc.)
/// are resolved through the native Dart `Platform` API.
/// {@endtemplate}
final class DefaultProcessInformation implements ProcessInformation {
  /// Current Resident Set Size memory (in bytes) at the moment this
  /// information object was created.
  final int _currentRss;

  /// Amount of memory (in bytes) the process has freed since the last
  /// sampling or previous measurement cycle.
  final int _freedMemory;

  /// Maximum Resident Set Size memory (in bytes) observed for the
  /// process up to the time this information object was created.
  final int _maxRss;

  /// Creates a new [DefaultProcessInformation] using the supplied RSS
  /// values and version string.
  ///
  /// {@macro default_process_information}
  DefaultProcessInformation(this._currentRss, this._freedMemory, this._maxRss);

  @override
  Integer getCurrentResidentSetSizeMemory() => Integer(_currentRss);

  @override
  String getDartVersion() => Platform.version;

  @override
  Integer getFreedMemory() => Integer(_freedMemory);

  @override
  String getLocalHostName() => Platform.localHostname;

  @override
  String getLocaleName() => Platform.localeName;

  @override
  Integer getMaxResidentSetSizeMemory() => Integer(_maxRss);

  @override
  Integer getNumberOfProcessors() => Integer(Platform.numberOfProcessors);

  @override
  String getOperatingSystem() => Platform.operatingSystem;

  @override
  String getOperatingSystemVersion() => Platform.operatingSystemVersion;

  @override
  Map<String, Object> toJson() => {
    "system.current.resident.set.size": _currentRss,
    "system.freed.memory": _freedMemory,
    "system.max.resident.set.size": _maxRss,
    "dart.version": Platform.version,
    "os.name": Platform.operatingSystem,
    "os.version": Platform.operatingSystemVersion,
    "system.locale": Platform.localeName,
    "system.hostname": Platform.localHostname,
    "system.processors": Platform.numberOfProcessors,
  };

  @override
  List<Object?> equalizedProperties() => [_currentRss, _freedMemory, _maxRss];
}