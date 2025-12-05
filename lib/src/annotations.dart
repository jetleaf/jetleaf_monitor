import 'package:jetleaf_lang/lang.dart';
import 'package:meta/meta_meta.dart';

/// {@template monitor_annotation}
/// Annotation used to **enable performance monitoring** for a class or method
/// within the JetLeaf runtime.
///
/// Applying `@Monitor()` instructs the monitoring subsystem to automatically
/// create and track a [`Performance`](../base/performance.dart) record for the
/// annotated target.  
///
/// ### Usage
///
/// #### Monitor an entire class
/// ```dart
/// @Monitor()
/// class UserRepository {
///   Future<void> loadUser() async { ... }
/// }
/// ```
/// In this case, monitoring will apply to all relevant method executions inside
/// the class, depending on how the `PerformanceTracker` is configured.
///
/// #### Monitor a specific method
/// ```dart
/// class AuthService {
///   @Monitor('AuthService.login')
///   Future<bool> login(String user, String pass) async { ... }
/// }
/// ```
/// A custom name may be supplied to group or rename performance metrics.
/// If omitted, the monitoring system derives a name automatically based on the
/// declaring type and method.
///
/// ### Behavior
/// - The annotation can be applied to **classes** or **methods**.
/// - When detected by the JetLeaf Pod/Performance infrastructure, an instance
///   of [`ConfigurablePerformance`](../base/configurable_performance.dart) is
///   created and updated during execution.
/// - If a custom name is provided, it becomes the metric key for lookup,
///   dashboards, and monitoring reports.
///
/// ### Notes
/// - Monitoring is purely declarative; consumers do not need to manually start
///   or stop timers.
/// - Naming should remain stable across releases for consistent analytics.
/// - This annotation integrates deeply with
///   `InstancePerformanceTracker` and `DefaultMonitoringService`.
///
/// {@endtemplate}
@Target({TargetKind.classType, TargetKind.method})
final class Monitor extends ReflectableAnnotation {
  /// Optional human-readable or dashboard-friendly identifier for the monitored
  /// class or method.
  ///
  /// If omitted, the monitoring framework generates a default name using the
  /// target's reflection metadata (typically `<ClassName>.<methodName>`).
  final String? name;

  /// Creates a new `Monitor` annotation.
  ///
  /// The optional [name] allows overriding the default metric identifier.
  /// 
  /// {@macro monitor_annotation}
  const Monitor([this.name]);

  @override
  Type get annotationType => Monitor;
}