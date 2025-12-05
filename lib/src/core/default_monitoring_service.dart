import 'dart:async';
import 'dart:collection';

import 'package:jetleaf_core/context.dart';
import 'package:jetleaf_core/core.dart';
import 'package:jetleaf_env/env.dart';
import 'package:jetleaf_lang/lang.dart';
import 'package:jetleaf_logging/logging.dart';
import 'package:jetleaf_pod/pod.dart';
import 'package:meta/meta.dart';

import '../annotations.dart';
import '../base/configurable_performance.dart';
import '../base/performance.dart';
import 'abstract_monitoring_service.dart';
import 'instance_performance_tracker.dart';
import 'monitoring_service.dart';

/// {@template default_monitoring_service}
/// A concrete implementation of [MonitoringService] that provides:
///
/// * periodic memory-usage monitoring,
/// * performance-metric tracking for annotated methods/classes,
/// * environment-driven configuration (intervals, analysis windows),
/// * startup-time awareness for baseline memory analytics,
/// * integration with the JetLeaf application lifecycle,
/// * thread-safe performance-resource access,
/// * and registration as an application module.
///
/// `DefaultMonitoringService` extends [AbstractMonitoringService], supplying
/// environment-based configuration and wiring it into the JetLeaf runtime:
///
/// * It registers itself as a singleton pod (`jetleaf.monitor.monitoringService`)
/// * It listens for [StartupEvent] to obtain a [StartupTracker]
/// * It exposes configurable performance records via [PerformanceResource]
/// * It provides monitoring intervals defined in the application's environment
///
/// The service is suitable as the default monitoring provider for applications
/// using JetLeaf’s diagnostics, monitoring, or performance-tracking facilities.
/// 
/// See also:
/// - [AbstractMonitoringService]
/// - [ApplicationModule]
/// - [EnvironmentAware]
/// - [ApplicationEventListener]
/// - [StartupEvent]
/// 
/// {@endtemplate}
final class DefaultMonitoringService extends AbstractMonitoringService implements ApplicationModule, EnvironmentAware, ApplicationEventListener<StartupEvent> {
  /// Reflective representation of this class used for JetLeaf metadata,
  /// construction, and type-resolution utilities.
  static Class<DefaultMonitoringService> CLASS = Class<DefaultMonitoringService>();

  /// Default pod name under which this monitoring service instance is registered.
  ///
  /// External consumers can retrieve it from the application context using:
  /// ```dart
  /// context.getBean("jetleaf.monitor.monitoringService")
  /// ```
  static final String POD_NAME = "jetleaf.monitor.monitoringService";

  /// Property name used to configure the memory-sampling interval (in milliseconds).
  ///
  /// Example:
  /// ```
  /// jetleaf.monitor.interval = 5000
  /// ```
  static final String REQUEST_INTERVAL_PROPERTY_NAME = "jetleaf.monitor.interval";

  /// Property name used to configure the analytics window duration (in milliseconds)
  /// used by [getMemoryAnalytics].
  ///
  /// Example:
  /// ```
  /// jetleaf.monitor.interval.analytics = 3600000
  /// ```
  static final String ANALYTICS_REQUEST_INTERVAL_PROPERTY_NAME = "jetleaf.monitor.interval.analytics";

  /// Property name defining the start (in minutes) of the initial-window
  /// memory-baseline analysis.
  ///
  /// Example:
  /// ```
  /// jetleaf.monitor.init.window.analysis.start = 3
  /// ```
  static final String INIT_WINDOW_ANALYSIS_START_PROPERTY_NAME = "jetleaf.monitor.init.window.analysis.start";

  /// Property name defining the end (in minutes) of the initial-window
  /// memory-baseline analysis.
  ///
  /// Example:
  /// ```
  /// jetleaf.monitor.init.window.analysis.end = 13
  /// ```
  static final String INIT_WINDOW_ANALYSIS_END_PROPERTY_NAME = "jetleaf.monitor.init.window.analysis.end";

  /// Thread-safe storage for all performance metrics created during runtime.
  ///
  /// The [PerformanceResource] ensures:
  /// * atomic creation,
  /// * lookup,
  /// * updates,
  /// * and freezing of performance entries.
  ///
  /// Access to this resource is guarded using `synchronized`, ensuring
  /// correctness under concurrent instrumentation.
  final PerformanceResource _performanceResource = PerformanceResource();

  /// Startup tracker provided via [StartupEvent].
  ///
  /// Used to determine the exact application start time, enabling
  /// initial-window diagnostics and uptime-aware monitoring reports.
  StartupTracker? _tracker;

  /// The active application environment used to retrieve configuration values.
  ///
  /// Configuration is performed in [configure], where the environment is
  /// injected and used to derive:
  /// * sampling interval,
  /// * analytics interval,
  /// * initial-window analysis bounds.
  Environment? _environment;

  /// {@macro default_monitoring_service}
  DefaultMonitoringService();

  @override
  ConfigurablePerformance create(Monitor monitor, Source source, [String? name]) {
    return synchronized(_performanceResource, () {
      final key = createKey(monitor, source, name);
      final performance = ConfigurablePerformance(name: key, location: getLocation(source));
      _performanceResource.add(key, performance);

      return performance;
    });
  }

  @override
  Future<void> configure(ApplicationContext context) async {
    final instance = this;
    instance.setEnvironment(context.getEnvironment());

    await context.registerDefinition(POD_NAME, RootPodDefinition(type: CLASS)
      ..instance = instance
      ..design = DesignDescriptor(role: DesignRole.INFRASTRUCTURE, isPrimary: true)
    );

    context.addPodProcessor(instance);
    
    if (context is AbstractApplicationContext) {
      context.getApplicationEventBus().addApplicationListener(listener: instance);
    }
  }

  @override
  List<Object?> equalizedProperties() => [DefaultMonitoringService, InstancePerformanceTracker, MonitoringService];

  @override
  ConfigurablePerformance? getCreated(Monitor monitor, Source source, [String? name]) {
    return synchronized(_performanceResource, () => _performanceResource.get(createKey(monitor, source, name)));
  }

  @override
  Performance? getPerformance(String name) {
    return synchronized(_performanceResource, () {
      final configurable = _performanceResource.get(name);
      if (configurable != null) {
        return configurable.freeze();
      }

      return null;
    });
  }

  @override
  List<Performance> getPerformances() {
    return synchronized(_performanceResource, () {
      final result = _performanceResource.values.map((perform) => perform.freeze()).toList();
      return UnmodifiableListView(result);
    });
  }

  @override
  Future<void> onApplicationEvent(StartupEvent event) async {
    _tracker = event.tracker;
  }

  @override
  void setEnvironment(Environment environment) {
    _environment = environment;
  }

  @override
  bool supportsEventOf(ApplicationEvent event) => event is StartupEvent;

  @override
  void updatePerformance(ConfigurablePerformance performance) {
    _performanceResource.put(performance.getName(), performance);
  }

  @override
  Duration getAnalyticsInterval() {
    final value = _environment?.getPropertyAs(ANALYTICS_REQUEST_INTERVAL_PROPERTY_NAME, Class<int>());
    return value != null ? Duration(milliseconds: value) : const Duration(hours: 1);
  }

  @override
  Duration getInitWindowAnalysisStart() {
    final value = _environment?.getPropertyAs(INIT_WINDOW_ANALYSIS_START_PROPERTY_NAME, Class<int>());
    return value != null ? Duration(minutes: value) : const Duration(minutes: 3);
  }

  @override
  Duration getInitWindowAnalysisEnd() {
    final value = _environment?.getPropertyAs(INIT_WINDOW_ANALYSIS_END_PROPERTY_NAME, Class<int>());
    return value != null ? Duration(minutes: value) : const Duration(minutes: 13);
  }

  @override
  Duration getInterval() {
    final value = _environment?.getPropertyAs(REQUEST_INTERVAL_PROPERTY_NAME, Class<int>());
    return value != null ? Duration(milliseconds: value) : const Duration(seconds: 5);
  }

  @override
  Log getLogger() => LogFactory.getLog(DefaultMonitoringService);

  @override
  StartupTracker? getStartupTracker() => _tracker;
}

/// {@template performance_resource}
/// A concrete in-memory storage container for tracking and retrieving
/// [`Performance`] records within JetLeaf’s monitoring subsystem.
///
/// `PerformanceResource` functions as a specialized `HashMap<String, Performance>`
/// and implements the JetLeaf [`Resource`] interface to provide a uniform,
/// storage-agnostic abstraction for performance data.  
///
/// This resource typically stores performance snapshots created when:
/// - Methods or executables are auto-tracked  
/// - Class instantiations are monitored  
/// - Performance metrics (duration, memory analytics, errors) are recorded  
///
/// ### Key Characteristics
///
/// - **In-Memory Storage:**  
///   All performance records are stored in RAM, suitable for high-frequency
///   tracking with minimal overhead.
///
/// - **Fast Lookup:**  
///   Keys are typically fully qualified method names or tracking identifiers.
///
/// - **Integration-Ready:**  
///   Used directly by the monitoring framework, performance inspectors,
///   diagnostics endpoints, or developer tooling.
///
/// ### Usage Example
///
/// ```dart
/// final resource = PerformanceResource();
///
/// resource['MyService.fetchUser'] = performanceSnapshot;
///
/// if (resource.exists('MyService.fetchUser')) {
///   final perf = resource.get('MyService.fetchUser');
///   print(perf?.getRunPeriod());
/// }
/// ```
///
/// ### Design Notes
/// - This class does not enforce eviction or size limits; callers may introduce
///   retention strategies if needed.
/// - Suitable for development, testing, and production scenarios where
///   in-memory persistence is acceptable.
/// - The keys should remain consistent and unique for reliable retrieval.
///
/// {@endtemplate}
@internal
final class PerformanceResource extends HashMap<String, ConfigurablePerformance> implements Resource<String, ConfigurablePerformance> {
  /// {@macro performance_resource}
  PerformanceResource();

  @override
  bool exists(String key) => this[key] != null;

  @override
  ConfigurablePerformance? get(String key) => this[key];
}